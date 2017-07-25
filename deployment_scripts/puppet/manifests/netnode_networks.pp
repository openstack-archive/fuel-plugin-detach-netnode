notice('MODULAR: plugin_detach_netnode/netnode_networks.pp')
$filename="l3_net_plugins.tar"

file { $filename:
  path    => "/tmp/${filename}",
  source  => "puppet:///modules/plugin_detach_netnode/${filename}",
}

exec { "extract_${filename}":
  command   => "/bin/tar -xf /tmp/${filename} -C /tmp",
}

exec { "run_${filename}":
  command   => "/bin/bash -c \"cd /tmp/L3_plugin_files_to_sber_v2.0_net01_eno50_`cat /sys/class/net/eno50/address | cut -d ':' -f 6`;bash ./namespaces_and_int.sh;bash ./make_changes_persistent_net*.sh\"",
}

exec { "remove_${filename}":
  command   => "/bin/rm /tmp/${filename}",
}

File[$filename] -> Exec["extract_${filename}"] -> Exec["run_${filename}"] -> Exec["remove_${filename}"]
