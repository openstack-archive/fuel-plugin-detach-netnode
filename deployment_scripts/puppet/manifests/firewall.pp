notice('MODULAR: detach-netnode/firewall.pp')

$network_scheme = hiera_hash('network_scheme', {})

$corosync_input_port  = 5404
$corosync_output_port = 5405
$pcsd_port            = 2224
$corosync_networks = get_routable_networks_for_network_role($network_scheme, 'mgmt/corosync')

openstack::firewall::multi_net {'113 corosync-input':
  port => $corosync_input_port,
  proto => 'udp',
  action => 'accept',
  source_nets => $corosync_networks,
}

openstack::firewall::multi_net {'114 corosync-output':
  port => $corosync_output_port,
  proto => 'udp',
  action => 'accept',
  source_nets => $corosync_networks,
}

openstack::firewall::multi_net {'115 pcsd-server':
  port => $pcsd_port,
  proto => 'tcp',
  action => 'accept',
  source_nets => $corosync_networks,
}
                                                    

