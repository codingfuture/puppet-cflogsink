#
# Copyright 2018 (c) Andrey Galkin
#


define cflogsink::endpoint (
    Enum[ 'logstash' ]
        $type = 'logstash',

    Integer[1]
        $memory_weight = 100,
    Optional[Integer[1]]
        $memory_max = undef,
    Cfsystem::CpuWeight
        $cpu_weight = 100,
    Cfsystem::IoWeight
        $io_weight = 100,

    Hash[String[1], Any]
        $settings_tune = {},

    Cfnetwork::Bindface
        $iface = $cflogsink::iface,

    Optional[Cfnetwork::Port]
        $port = undef,
    Optional[Cfnetwork::Port]
        $ssl_port = undef,

    Optional[ Hash[String[1],Any] ]
        $dbaccess = undef,
) {
    include "cflogsink::${type}"

    $service_name = "cf${type}-${title}"
    $user = "${type}_${title}"

    $root_dir = "/var/lib/${user}"

    #---
    group { $user:
        ensure => present,
    }

    user { $user:
        ensure         => present,
        gid            => $user,
        home           => $root_dir,
        system         => true,
        shell          => '/bin/dash',
        purge_ssh_keys => true,
        require        => Group[$user],
    }

    #---
    $user_dirs = [
        $root_dir,
        "${root_dir}/config",
        "${root_dir}/logs",
        "${root_dir}/data",
    ]
    file { $user_dirs:
        ensure => directory,
        owner  => $user,
        group  => $user,
        mode   => '0750',
    }
    -> cfsystem::puppetpki{ $user: }

    #---
    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 256,
        max_mb => $memory_max,
    }

    #---
    $ssl_clients = cfsystem::query([
        'from', 'resources', ['extract', [ 'certname', 'parameters' ],
            ['and',
                ['=', 'type', 'Cflogsink::Client'],
                ['=', ['parameter', 'target'], $::facts['fqdn']],
                ['=', ['parameter', 'ssl'], true],
            ],
    ]])
    $ssl_client_hosts = $ssl_clients.reduce( [] ) |$memo, $v| {
        $memo + $ssl_clients['certname']
    }

    if $iface == 'any' {
        $listen = undef
    } else {
        $listen = cfnetwork::bind_address($iface)
    }

    $fact_port = cfsystem::gen_port($service_name, $port)
    $fact_ssl_port = cfsystem::gen_port("${service_name}:ssl", $ssl_port)

    ensure_resource('cfnetwork::describe_service', $user, {
        server => "tcp/${fact_port}",
    })
    ensure_resource('cfnetwork::describe_service', "${user}_ssl", {
        server => "tcp/${fact_ssl_port}",
    })

    cfnetwork::service_port { "local:${user}": }
    cfnetwork::client_port { "local:${user}":
        user => $user,
    }

    cfnetwork::service_port { "${iface}:${user}":
        src => 'ipset:localnet',
    }

    $ipset_ssl_clients = "${user}_ssl"
    cfnetwork::ipset { $ipset_ssl_clients:
        addr => $ssl_client_hosts.sort(),
    }
    cfnetwork::service_port { "${iface}:${user}_ssl":
        src => "ipset:${ipset_ssl_clients}",
    }

    #---
    if $dbaccess {
        create_resources(
            'cfdb::access',
            {
                main  => {
                    local_user    => $user,
                    notify => Cflogsink_endpoint[ $service_name ],
                },
            },
            $dbaccess
        )
    }

    #---
    cflogsink_endpoint { $service_name:
        ensure        => present,
        type          => $type,
        user          => $user,
        service_name  => $service_name,


        memory_weight => $memory_weight,
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,

        root_dir      => $root_dir,

        settings_tune => merge(
            $settings_tune,
            {
                cfdb => merge(
                    {
                        'listen'   => $listen,
                    },
                    pick($settings_tune['cfdb'], {}),
                    {
                        'port'     => $fact_port,
                        'ssl_port' => $ssl_port,
                    },
                )
            }
        ),

        location      => $cfdb::location,

        require       => [
            User[$user],
            File[$user_dirs],
            Cfsystem_memory_weight[$service_name],
            Cfsystem::Puppetpki[$user],
            Anchor['cfnetwork:firewall'],
        ],
    }
}
