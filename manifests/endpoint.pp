#
# Copyright 2018 (c) Andrey Galkin
#


define cflogsink::endpoint (
    Enum[ 'logstash' ]
        $type = 'logstash',
    Optional[String[1]]
        $config = undef,

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
        $secure_port = undef,

    Optional[ Hash[String[1],Any] ]
        $dbaccess = undef,

    Array[String[1]]
        $extra_clients = [],

    Array[String[1]]
        $extra_secure_clients = [],
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
    if $iface == 'any' {
        $listen = undef
    } else {
        $listen = cfnetwork::bind_address($iface)
    }

    #---
    $secure_clients = cfsystem::query([
        'from', 'resources',
            ['extract', [ 'certname', 'parameters' ],
                ['and',
                    ['=', 'title', 'Cflogsink::Client'],
                    ['=', 'type', 'Class'],
                    ['or',
                        [ '=', ['parameter', 'host'], $::facts['fqdn'] ],
                        [ '=', ['parameter', 'host'], $listen ],
                    ],
                    ['=', ['parameter', 'tls'], true],
                ],
            ],
    ])
    $secure_client_hosts = $secure_clients.reduce( [] ) |$memo, $v| {
        $memo + $v['certname']
    }

    $fact_port = cfsystem::gen_port($service_name, $port)
    $fact_secure_port = cfsystem::gen_port("${service_name}:secure", $secure_port)
    $fact_control_port = cfsystem::gen_port("${service_name}:control")

    ensure_resource('cfnetwork::describe_service', $user, {
        server => "tcp/${fact_port}",
    })
    ensure_resource('cfnetwork::describe_service', "${user}_tls", {
        server => "tcp/${fact_secure_port}",
    })

    cfnetwork::service_port { "local:${user}": }
    cfnetwork::client_port { "local:${user}":
        user => $user,
    }

    $access_ipset = "cflog_${title}_access"
    cfnetwork::ipset { $access_ipset:
        addr => ['ipset:localnet'] + $extra_clients,
    }
    cfnetwork::service_port { "${iface}:${user}":
        src => ["ipset:${access_ipset}"],
    }

    $ipset_secure_clients = "cflog_${title}_tlsaccess"
    cfnetwork::ipset { $ipset_secure_clients:
        addr => $secure_client_hosts.sort() + $extra_secure_clients,
    }
    cfnetwork::service_port { "${iface}:${user}_tls":
        src => "ipset:${ipset_secure_clients}",
    }

    #---
    if $dbaccess {
        create_resources(
            'cfdb::access',
            {
                main  => {
                    local_user      => $user,
                    use_unix_socket => false,
                    notify          => Cflogsink_endpoint[ $title  ],
                },
            },
            $dbaccess
        )
    }

    #---
    file { "${root_dir}/config/pipeline.conf":
        owner   => $user,
        group   => $user,
        mode    => '0640',
        content => epp(pick($config, "cflogsink/${type}_default.conf")),
        notify  => Service[ $service_name ],
    }
    -> cflogsink_endpoint { $title:
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
                cflogsink => merge(
                    {
                        'listen'   => $listen,
                    },
                    pick($settings_tune['cflogsink'], {}),
                    {
                        'port'         => $fact_port,
                        'secure_port'  => $fact_secure_port,
                        'control_port' => $fact_control_port,
                    },
                )
            }
        ),

        location      => $cfsystem::location,

        require       => [
            User[$user],
            File[$user_dirs],
            Cfsystem_memory_weight[$service_name],
            Cfsystem::Puppetpki[$user],
            Anchor['cfnetwork:firewall'],
        ],
    }
    -> service { $service_name:
        require => Cfsystem_flush_config['commit'],
    }

    #---
    include cfsystem::custombin
    file { "${cfsystem::custombin::bin_dir}/cflog_${title}":
        mode    => '0755',
        content => epp('cflogsink/cflog.sh.epp', {
            user     => $user,
            env_file => "${root_dir}/.env",
        }),
    }
}
