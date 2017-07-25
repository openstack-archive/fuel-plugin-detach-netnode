# Manifest that creates hiera config overrride
class plugin_detach_netnode::controller_override {

# Initial constants
$plugin_name     = 'fuel-plugin-detach-netnode'
$plugin_settings = hiera_hash("${plugin_name}", {})
$hiera_dir              = '/etc/hiera/plugins'

$hiera_content = inline_template("
neutron_controller_roles: ['controller','network-node','primary-controller', 'primary-network-node']
neutron_advanced_configuration:
  l2_agent_ha: false
  l3_agent_ha: false
  dhcp_agent_ha: false
  metadata_agent_ha: false
run_ping_checker: false
")

  file { "${hiera_dir}/${plugin_name}.yaml":
    ensure  => file,
    content => "${hiera_content}\n",
  }
}

