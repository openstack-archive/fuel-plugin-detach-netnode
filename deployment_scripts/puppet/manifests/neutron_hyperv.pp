notice('MODULAR: plugin_detach_netnode/neutron_hyperv.pp')
neutron_plugin_ml2 {
  'ml2/mechanism_drivers': value => 'openvswitch, hyperv';
}
service { 'neutron-server': }

Neutron_plugin_ml2 <||> ~> Service<||>
