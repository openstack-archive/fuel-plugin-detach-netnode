notice('MODULAR: plugin_detach_netnode/neutron_mtu.pp')
neutron_plugin_ml2 {
  'DEFAULT/path_mtu': value => 1550;
}

neutron_config   {
  'DEFAULT/global_physnet_mtu': value => 9000;
}

service { 'neutron-server': }

Neutron_plugin_ml2 <||> ~> Service<||>
Neutron_config <||> ~> Service<||>
