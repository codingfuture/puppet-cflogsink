#
# Copyright 2018-2019 (c) Andrey Galkin
#


define cflogsink::endpoint (
    Enum[ 'logstash', 'proxy' ]
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
    Optional[Cfnetwork::Port]
        $internal_port = undef,

    Optional[ Hash[String[1],Any] ]
        $dbaccess = undef,

    Array[String[1]]
        $extra_clients = [],

    Array[String[1]]
        $extra_secure_clients = [],
) {
    include cflogsink
    include "cflogsink::internal::${type}"
    include cflogsink::rsyslog
    include cflogsink::internal::imrelpmodule

    $service_name = "cf${type}-${title}"

    if $type != 'proxy' {
        $user = "${type}_${title}"

        $root_dir = "/var/lib/${user}"

        #---
        group { $user:
            ensure => present,
        }
        -> user { $user:
            ensure         => present,
            gid            => $user,
            home           => $root_dir,
            system         => true,
            shell          => '/bin/dash',
            purge_ssh_keys => true,
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

        #---
        cfsystem_memory_weight { $service_name:
            ensure => present,
            weight => $memory_weight,
            min_mb => 256,
            max_mb => $memory_max,
        }
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
    } + $::facts['fqdn']

    $fact_port = cfsystem::gen_port($service_name, $port)
    $fact_secure_port = cfsystem::gen_port("${service_name}:secure", $secure_port)

    $fw_service = "cflog_${title}"

    ensure_resource('cfnetwork::describe_service', $fw_service, {
        server => "tcp/${fact_port}",
    })
    ensure_resource('cfnetwork::describe_service', "${fw_service}_tls", {
        server => "tcp/${fact_secure_port}",
    })

    cfnetwork::service_port { "local:${fw_service}": }
    cfnetwork::client_port { "local:${fw_service}":
        user => [ 'root' ],
    }

    cflogsink::internal::endpoint { $title:
        type          => $type,
        location      => $cfnetwork::location,
        location_pool => $cfnetwork::location_pool,
        listen        => $listen,
        port          => $fact_port,
        secure_port   => $fact_secure_port,
    }

    if $iface != 'local' {
        $access_ipset = "${fw_service}_access"
        cfnetwork::ipset { $access_ipset:
            addr => ['ipset:localnet'] + $extra_clients,
        }
        cfnetwork::service_port { "${iface}:${fw_service}":
            src => ["ipset:${access_ipset}"],
        }

        $ipset_secure_clients = "${fw_service}_tlsaccess"
        cfnetwork::ipset { $ipset_secure_clients:
            addr => $secure_client_hosts.sort() + $extra_secure_clients,
        }
        cfnetwork::service_port { "${iface}:${fw_service}_tls":
            src => "ipset:${ipset_secure_clients}",
        }
    }

    if $type == 'logstash' {
        $internal_listen = '127.0.0.1'
        $fact_internal_port = cfsystem::gen_port("${service_name}:internal", pick_default($internal_port, $fact_port))
        $fact_control_port = cfsystem::gen_port("${service_name}:control")

        ensure_resource('cfnetwork::describe_service', "${fw_service}_internal", {
            server => "tcp/${fact_internal_port}",
        })
        cfnetwork::service_port { "local:${fw_service}_internal": }
        cfnetwork::client_port { "local:${fw_service}_internal":
            user => [ $user, 'root' ],
        }
        ensure_resource('cfnetwork::describe_service', "${fw_service}_control", {
            server => "tcp/${fact_internal_port}",
        })
        cfnetwork::service_port { "local:${fw_service}_control": }
        cfnetwork::client_port { "local:${fw_service}_control":
            user => [ $user, 'root' ],
        }

        #---
        if $dbaccess {
            create_resources(
                'cfdb::access',
                {
                    "${service_name}"  => {
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
            content => epp(pick($config, "cflogsink/${type}_default.conf"), {
                root_dir => $root_dir,
            }),
            notify  => Service[ $service_name ],
        }
        -> file { "${root_dir}/config/tpl-access.json":
            owner   => $user,
            group   => $user,
            mode    => '0640',
            content => file('cflogsink/access-template-es6x.json'),
            notify  => Service[ $service_name ],
        }
        -> file { "${root_dir}/config/tpl-fw.json":
            owner   => $user,
            group   => $user,
            mode    => '0640',
            content => file('cflogsink/fw-template-es6x.json'),
            notify  => Service[ $service_name ],
        }
        -> file { "${root_dir}/config/tpl-log.json":
            owner   => $user,
            group   => $user,
            mode    => '0640',
            content => file('cflogsink/log-template-es6x.json'),
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
                            'listen'          => $listen,
                            'internal_listen' => $internal_listen,
                        },
                        pick($settings_tune['cflogsink'], {}),
                        {
                            'port'          => $fact_port,
                            'secure_port'   => $fact_secure_port,
                            'internal_port' => $fact_internal_port,
                            'control_port'  => $fact_control_port,
                        },
                    )
                }
            ),

            location      => $cfsystem::location,

            require       => [
                User[$user],
                File[$user_dirs],
                Cfsystem_memory_weight[$service_name],
                #Cfsystem::Puppetpki[$user],
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

        #---
        $rsyslog_rule = $service_name

        file { "/etc/rsyslog.d/48_${rsyslog_rule}.conf":
            mode    => '0640',
            content => epp('cflogsink/omfwd.conf.epp', {
                rule_name   => $rsyslog_rule,
                target      => pick($internal_listen, '127.0.0.1'),
                target_port => $fact_internal_port,
                tune        => merge( {
                    'queue.size'             => 10000,
                    'queue.dequeuebatchsize' => 1000,
                    'queue.maxdiskspace'     => '1g',
                    'queue.timeoutenqueue'   => 0,
                    'queue.saveonshutdown'   => 'on',
                    'queue.type'             => 'LinkedList',
                    'queue.filename'         => $service_name,
                }, pick($settings_tune['cfomwd'], {}) ),
            }),
        }
        ~> Exec['cflogsink:rsyslog:refresh']
    } else {
        $rsyslog_rule = 'sink'
    }

    #---
    file { "/etc/rsyslog.d/49_${service_name}_plain.conf":
        mode    => '0640',
        content => epp('cflogsink/imrelp.conf.epp', {
            rule_name => $rsyslog_rule,
            listen    => pick($listen, '0.0.0.0'),
            port      => $fact_port,
            tune      => {
                'maxdatasize'        => '128k',
                'keepalive'          => 'on',
                'keepalive.interval' => 30,
                'keepalive.time'     => 30,
            },
        }),
    }
    ~> Exec['cflogsink:rsyslog:refresh']

    file { "/etc/rsyslog.d/49_${service_name}_tls.conf":
        mode    => '0640',
        content => epp('cflogsink/imrelp.conf.epp', {
            rule_name => $rsyslog_rule,
            listen    => pick($listen, '0.0.0.0'),
            port      => $fact_secure_port,
            tune      => {
                'maxdatasize'        => '128k',
                'tls'                => 'on',
                'tls.compression'    => 'on',
                'tls.dhbits'         => 2048,
                'tls.authmode'       => 'name',
                'tls.permittedpeer'  => cfsystem::stable_sort($secure_client_hosts),
                'tls.cacert'         => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
                'tls.mycert'         => "/etc/puppetlabs/puppet/ssl/certs/${::facts['fqdn']}.pem",
                'tls.myprivkey'      => "/etc/puppetlabs/puppet/ssl/private_keys/${::facts['fqdn']}.pem",
                'keepalive'          => 'on',
                'keepalive.interval' => 30,
                'keepalive.time'     => 30,
            },
        }),
    }
    ~> Exec['cflogsink:rsyslog:refresh']
}
