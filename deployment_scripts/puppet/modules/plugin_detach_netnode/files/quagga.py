# Copyright (C) 2014 eNovance SAS <licensing@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import errno
import itertools
import os
import os.path
from socket import error as socket_error
import stat

import netaddr
from oslo_config import cfg
from oslo_log import log as logging

import jinja2

from neutron.agent.l3 import legacy_router
from neutron.agent.linux import external_process
from neutron.agent.linux import utils
from neutron.common import exceptions
from neutron.i18n import _LW


OPTS = [
    cfg.StrOpt('zebra_bin',
               default='/usr/lib/quagga/zebra',
               help=_('Path to Zebra binary')),

    cfg.StrOpt('zebra_config',
               default='/etc/quagga/zebra.conf',
               help=_('Path to Zebra configuration file')),

    cfg.StrOpt('ospfd_bin',
               default='/usr/lib/quagga/ospfd',
               help=_('Path to OSPFd binary')),

    cfg.StrOpt('ospfd_config',
               default='/etc/quagga/ospfd.conf',
               help=_('Path to OSPFd configuration file')),

    cfg.StrOpt('ospfd_listen_address',
               default='127.0.0.1',
               help=_('Address for ospfd to listen to')),

    cfg.StrOpt('vty_password',
               default='',
               help=_('Password for vty access')),

    cfg.StrOpt('config_template',
               default='/etc/neutron/quagga.conf.template',
               help=_('Path to Quagga configuration template')),

    cfg.StrOpt('state_dir',
               default='/var/run/neutron-quagga',
               help=_("Path to state dir for quagga pids, sockets etc")),

    cfg.StrOpt('username',
               default='neutron',
               help=_("zebra and ospfd will be started under this user. "))
]

CONF = cfg.CONF
CONF.register_opts(OPTS, 'quagga')

LOG = logging.getLogger(__name__)

template_telnet_command = """
import telnetlib
import sys
tn = telnetlib.Telnet('{hostname}', '{port}');
tn.read_until('Password:');
[tn.write(line) for line in sys.stdin.readlines()];
print tn.read_all()
"""


class ConfigSectionNotFound(exceptions.NeutronException):
    message = _("Quagga template is missing named block '%(section)s'")


class QuaggaConfigTemplate(object):
    def __init__(self):
        template_path, template_name = os.path.split(
            CONF.quagga.config_template
        )

        self._env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(template_path)
        )
        self._template = self._env.get_template(template_name)

    def render(self, section, data_dict):
        for name, render in self._template.blocks.iteritems():
            if name == section:
                return render(self._template.new_context(data_dict))

        raise ConfigSectionNotFound(section=section)


class QuaggaProcess(object):
    """A generic class to control individual Quagga process
    """

    enable_vty = False

    def __init__(self, resource_id, binary_path, config_path,
                 namespace=None, listen_address=None):
        self.resource_id = resource_id
        self.binary_path = binary_path
        self.config_path = config_path
        self.namespace = namespace
        self.listen_address = listen_address
        self._spawned = False

    def spawn(self):
        zebra_api_file = utils.get_conf_file_name(CONF.quagga.state_dir,
                                                  self.resource_id,
                                                  'zebra.api',
                                                  ensure_conf_dir=True)
        self._process = self.get_process(CONF,
                                         self.resource_id,
                                         self.namespace,
                                         CONF.quagga.state_dir)

        def callback(pid_file):
            cmd = [self.binary_path,
                   '-f', self.config_path,
                   '-i', pid_file,
                   '-d',
                   '-z', zebra_api_file,
                   '-u', CONF.quagga.username]
            if self.enable_vty:
                cmd += ['-A', self.listen_address]
            else:
                # disable vty server
                cmd += ['-P', '0']
            return cmd

        self._process.enable(callback, reload_cfg=True)

        self._spawned = True
        LOG.debug('Quagga process %s spawned with config %s',
                  self.resource_id, self.config_path)

    def spawn_or_restart(self):
        if self._process:
            self.restart()
        else:
            self.spawn()

    def restart(self):
        if self._process.active:
            self._process.reload_cfg()
        else:
            LOG.warn(_LW('A previous instance of Quagga process %s '
                         'seems to be dead, unable to restart it, a '
                         'new instance will be spawned'), self.resource_id)
            self._process.disable()
            self.spawn()

    def disable(self):
        if self._process:
            self._process.disable(sig='15')
            self._spawned = False

    def revive(self):
        if self.spawned and not self._process.active:
            self.restart()

    @classmethod
    def get_process(cls, conf, resource_id, namespace, pids_path):
        return external_process.ProcessManager(
            conf,
            resource_id,
            namespace,
            service=cls.service,
            pids_path=pids_path)

    @property
    def spawned(self):
        return self._spawned

    def configure(self, commands):
        """Pushes configuration to a Quagga service instance"""
        raise NotImplementedError()


class ZebraProcess(QuaggaProcess):
    service = 'zebra'


class OspfdProcess(QuaggaProcess):
    service = 'ospfd'
    enable_vty = True

    def configure(self, commands=[]):
        commands = itertools.chain([CONF.quagga.vty_password], commands,
                                   ["exit"])
        vty_commands = '\n'.join(commands) + '\n'
        telnet_command = template_telnet_command.format(
            hostname=CONF.quagga.ospfd_listen_address,
            port='2604')
        res = utils.execute(["ip", "netns", "exec", self.namespace, "python",
                            "-c", telnet_command],
                            process_input=vty_commands, run_as_root=True)
        return res


class QuaggaRouter(legacy_router.LegacyRouter):
    """Responsible for
    - translation of Neutron router events into Quagga services configuration
    - managing the lifecycle of relevant Quagga processes
    """
    def __init__(self, *args, **kwargs):
        super(QuaggaRouter, self).__init__(*args, **kwargs)

        self.ospf_config_template = QuaggaConfigTemplate()

        self.zebra = ZebraProcess(
            self.router_id, CONF.quagga.zebra_bin, CONF.quagga.zebra_config,
            self.ns_name)
        self.ospfd = OspfdProcess(
            self.router_id, CONF.quagga.ospfd_bin, CONF.quagga.ospfd_config,
            self.ns_name, listen_address=CONF.quagga.ospfd_listen_address)
        self.ignore_ospf_configuration = False

    def initialize(self, process_monitor):
        super(QuaggaRouter, self).initialize(process_monitor)
        self.zebra.spawn()
        self.ospfd.spawn()

    def delete(self, agent):
        self.ignore_ospf_configuration = True
        self.ospfd.disable()
        self.zebra.disable()
        utils.remove_conf_files(CONF.quagga.state_dir, self.router_id)
        super(QuaggaRouter, self).delete(agent)

    def internal_network_added(self, port):
        super(QuaggaRouter, self).internal_network_added(port)
        interface_name = self.get_internal_device_name(port['id'])
        self._configure_ospfd('add_port', locals())

        LOG.debug("Added port with interface name %s to router %s",
                  interface_name, self.router_id)

    def internal_network_removed(self, port):
        interface_name = self.get_internal_device_name(port['id'])
        self._configure_ospfd('delete_port', locals())

        super(QuaggaRouter, self).internal_network_removed(port)
        LOG.debug("Deleted port with interface name %s from router %s",
                  interface_name, self.router_id)

    def external_gateway_added(self, ex_gw_port, interface_name):
        super(QuaggaRouter, self).external_gateway_added(ex_gw_port,
                                                         interface_name)
        self._configure_ospfd('add_ext_port', locals())

        LOG.debug("Added ext port with interface name %s to router %s",
                  interface_name, self.router_id)

    def external_gateway_removed(self, ex_gw_port, interface_name):
        self._configure_ospfd('delete_ext_port', locals())
        super(QuaggaRouter, self).external_gateway_removed(ex_gw_port,
                                                           interface_name)
        LOG.debug("Deleted ext port with interface name %s from router %s",
                  interface_name, self.router_id)

    def _configure_ospfd(self, action, data):
        if self.ignore_ospf_configuration:
            return
        config = self.ospf_config_template.render(action, data)
        if config:
            self.ospfd.configure(config)
