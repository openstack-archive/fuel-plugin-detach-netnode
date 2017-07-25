# Manifest that creates hiera config overrride
class plugin_detach_netnode::override {

# Initial constants
$plugin_name     = 'fuel-plugin-detach-netnode'
$plugin_settings = hiera_hash("${plugin_name}", {})
$hiera_dir              = '/etc/hiera/plugins'

$hiera_content = inline_template("
neutron_controller_roles: ['controller','network-node','primary-controller', 'primary-network-node']
neutron_advanced_configuration:
  l2_agent_ha: true
  l3_agent_ha: true
  dhcp_agent_ha: true
  metadata_agent_ha: true
run_ping_checker: false
colocate_haproxy: false
corosync_roles: ['network-node', 'primary-network-node']
neutron_primary_controller_roles: ['primary-network-node']
neutron_nodes: 
<%=  scope.function_hiera_hash(['network_metadata'])['nodes'].inject({}) {|res, (k, v)| res[v['name']] = v if (v['node_roles']  & ['controller','network-node','primary-network-node','primary-controller']).any?; res }.to_yaml.split('\n')[1..-1].join('\n') %>
")

  file { "${hiera_dir}/${plugin_name}.yaml":
    ensure  => file,
    content => "${hiera_content}\n",
  }
}

