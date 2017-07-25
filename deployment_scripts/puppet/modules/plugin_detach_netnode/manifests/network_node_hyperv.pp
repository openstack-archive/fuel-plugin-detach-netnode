class plugin_detach_netnode::network_node_hyperv {

  $plugin_settings = hiera('fuel-plugin-detach-netnode')
  Exec { path => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' }

  if $plugin_settings['hyperv_region'] == true {

    $packages = ['gcc','python-dev','python-pip']

    package { $packages:
              ensure => present,
    }->
    file {"copy networking-hyperv.tar":
           path => '/tmp/networking-hyperv.tar',
           source => 'puppet:///modules/plugin_detach_netnode/networking-hyperv.tar',
    }->
    file {"copy dependencies":
           path => '/tmp/networking_hyperv_dependecies.tar',
           source => 'puppet:///modules/plugin_detach_netnode/networking_hyperv_dependecies.tar',
    }->
    exec {"uncompress networking_hyperv packages":
          command => "tar -xf /tmp/networking-hyperv.tar -C /tmp/",
    }->
    exec {"uncompress networking_hyperv_dependecies":
          command => "tar -xf /tmp/networking_hyperv_dependecies.tar -C /tmp/",
    }->
    exec {"install pbr":
          command => "pip install --no-index --find-links='/tmp/networking_hyperv_dependecies' pbr==1.6.0",
    }->
    exec { 'install networking_hyperv':
          command => 'python setup.py install',
          cwd => '/tmp/networking-hyperv',
          path => '/usr/bin',
    }->
    exec { "remove temp dir":
      command   => "/bin/rm -rf /tmp/networking-hyperv* /tmp/networking_hyperv*",
    }
  }
}
