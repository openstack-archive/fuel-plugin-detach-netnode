notice('MODULAR: plugin_detach_netnode/neutron_networks.pp')

$filename="make_networks_v2.sh"

file { $filename:
  path    => "/tmp/${filename}",
  source  => "puppet:///modules/plugin_detach_netnode/${filename}",
}

exec { "run_${filename}":
  command   => "/bin/bash /tmp/${filename}",
}

exec { "remove_${filename}":
  command   => "/bin/rm /tmp/${filename}",
}

File[$filename]  -> Exec["run_${filename}"] -> Exec["remove_${filename}"]
