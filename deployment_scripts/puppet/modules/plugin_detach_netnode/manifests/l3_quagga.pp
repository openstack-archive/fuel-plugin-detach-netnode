class plugin_detach_netnode::l3_quagga {

  $plugin_settings = hiera('fuel-plugin-detach-netnode')
  $password=$plugin_settings['quagga_password']
  Exec { path => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' }

  if $plugin_settings['l3_agent_quagga'] == true {
  
    package { "quagga":
              ensure => present,
    }
    file {'quagga.py':
          path    => '/usr/lib/python2.7/dist-packages/neutron/agent/linux/quagga.py',
          mode    => '0644',
          group   => root,
          source  => 'puppet:///modules/plugin_detach_netnode/quagga.py',
          require => Package["quagga"],
    }
    file {'quagga.filters':
          path    => '/etc/neutron/rootwrap.d/quagga.filters',
          mode    => '0644',
          group   => root,
          source  => 'puppet:///modules/plugin_detach_netnode/quagga.filters',
          require => Package["quagga"],
    }
    file {'ospfd_idz.conf':
          path    => '/etc/quagga/ospfd_idz.conf',
          mode    => '0644',
          group   => root,
          source  => 'puppet:///modules/plugin_detach_netnode/ospfd_idz.conf',
          require => Package["quagga"],
    }
    file_line {"ospfd_idz vty pass":
          path  => "/etc/quagga/ospfd_idz.conf",
          line  => "password $password",
          match => "password ",
          require => File["ospfd_idz.conf"],
    }
    file {'ospfd_ipz.conf':
          path    => '/etc/quagga/ospfd_ipz.conf',
          mode    => '0644',
          group   => root,
          source  => 'puppet:///modules/plugin_detach_netnode/ospfd_ipz.conf',
          require => Package["quagga"],
    }
    file_line {"ospfd_ipz vty pass":
          path  => "/etc/quagga/ospfd_ipz.conf",
          line  => "password $password",
          match => "password ",
          require => File["ospfd_ipz.conf"],
    }
    file {'quagga.conf.template':
          path    => '/etc/neutron/quagga.conf.template',
          mode    => '0644',
          group   => root,
          source  => 'puppet:///modules/plugin_detach_netnode/quagga.conf.template',
          require => Package["quagga"],
    }
    exec  {"sed import quagga":
          command => "sed -i '44i from neutron.agent.linux import quagga' /usr/lib/python2.7/dist-packages/neutron/agent/l3/agent.py",
          require => Package["quagga"],
    }
    file_line {"adding quagga return":
          path  => "/usr/lib/python2.7/dist-packages/neutron/agent/l3/agent.py",
          line  => "        return quagga.QuaggaRouter(*args, **kwargs)",
          match => "return legacy_router.LegacyRouter.*",
          require => Package["quagga"],
    }
    file {'zebra.conf':
          path    => '/etc/quagga/zebra.conf',
          mode    => '0755',
          owner   => root,
          group   => root,
          source  => '/usr/share/doc/quagga/examples/zebra.conf.sample',
          require => Package["quagga"],
    }
    file {'ospfd.conf':
          path    => '/etc/quagga/ospfd.conf',
          mode    => '0644',
          group   => root,
          source  => 'puppet:///modules/plugin_detach_netnode/ospfd.conf',
          require => Package["quagga"],
    }
    file {'/var/run/neutron-quagga':
          ensure  => directory,
          require => Package["quagga"],
          owner   => 'neutron',
          group   => 'neutron',
    }
  }
}
