Detached network node plugin for Fuel
=====================================

Overview
--------

Detached network node plugin for Fuel extends Mirantis OpenStack functionality and flexibility
by detaching l3 functions from controller nodes. It detaches neutron l3, dhcp and metadata agents
from controllers and attached them to new node role (network-node role). Also, it installs l3 quagga
neutron agent.


Compatible Fuel versions
------------------------

9.0


User Guide
----------

1. Create an environment.
2. Enable the plugin on the Networks/Other tab of the Fuel web UI and fill in form
    fields:
   * Install quagga with ospf support (optional)
   * Quagga vty password -password for quagga vty console
3. Select new node with role Network Node
4. Deploy the environment.


Installation Guide
==================

To install Detached Network Node plugin, follow these steps:

1. Download the plugin
    git clone https://github.com/openstack/fuel-plugin-detached-network-node

2. Make changes to network creation script deployment_scripts/puppet/modules/plugin_detach_netnode/files/make_networks_v2.sh

3. Put quagga packages into repositories/ubuntu

4. Build the plugin

5. Copy the plugin on already installed Fuel Master node; ssh can be used for
    that. If you do not have the Fuel Master node yet, see
    [Quick Start Guide](https://software.mirantis.com/quick-start/):

        # scp fuel-plugin-detached-network-node-0.6.4-1.noarch.rpm root@<Fuel_master_ip>:/tmp

6. Log into the Fuel Master node. Install the plugin:

        # cd /tmp
        # fuel plugins --install fuel-plugin-detached-network-node-0.6.4-1.noarch.rpm

7. Check if the plugin was installed successfully:

        # fuel plugins
        id | name                                | version | package_version
        ---|-------------------------------------|---------|----------------
        1  | fuel-plugin-detached-network-node   | 0.6.4   | 4.0.0


Requirements
------------

| Requirement                      | Version/Comment |
|:---------------------------------|:----------------|
| Mirantis OpenStack compatibility | 9.0             |


Limitations
-----------

Minimal number of network node nodes >= 1


Contacts
--------

TBD
