#
# Copyright 2018-2019 (c) Andrey Galkin
#


class cflogsink (
    Cfnetwork::Bindface
        $iface = $cflogsink::internal::defaults::iface,
    Variant[ Boolean, Hash ]
        $server = false,
    Optional[String[1]]
        $target = undef,
    Optional[Boolean]
        $tls = undef,
) inherits cflogsink::internal::defaults {
    include cfnetwork
    include cfsystem

    $centralized = !!$target

    #---
    include cflogsink::rsyslog
    Package['rsyslog']
    ->exec { 'cflogsink:rsyslog:refresh':
        command     => '/bin/systemctl reload-or-restart rsyslog.service',
        refreshonly => true,
    }

    #---
    ensure_resource('package', 'ulogd2')
    Package['ulogd2']
    -> exec { 'cflogsink:ulogd:refresh':
        command     => '/bin/systemctl reload-or-restart ulogd.service',
        refreshonly => true,
    }

    #---
    if $server {
        if $server =~ Hash {
            $server_conf = $server
        } else {
            $server_conf = {}
        }

        if $target != $::facts['fqdn'] {
            $server_type = 'proxy'
            $endpoint_name = 'proxy'
        } else {
            $server_type = 'logstash'
            $endpoint_name = 'main'
        }

        $merged_config = merge(
            {
                iface         => $cflogsink::iface,
                type          => $server_type,
                port          => 2514,
                secure_port   => 3514,
                internal_port => 4514,
                dbaccess      => {
                    cluster => 'logsink',
                },
            },
            $server_conf
        )

        create_resources(
            'cflogsink::endpoint',
            { $endpoint_name => $merged_config }
        )
    }

    if $target {
        if $target == $::facts['fqdn'] and $server {
            $merged_iface = $merged_config['iface']
            $sink = [{
                'parameters' => merge({
                    'listen'        => $merged_iface ? {
                        'any'   => undef,
                        default => cfnetwork::bind_address($merged_iface),
                    },
                    'location'      => $cfnetwork::location,
                    'location_pool' => $cfnetwork::location_pool,
                }, $merged_config)
            }]
        } else {
            $sink = cfsystem::query([
                'from', 'resources', ['extract', [ 'parameters' ],
                    ['and',
                        ['=', 'type', 'Cflogsink::Internal::Endpoint'],
                        ['=', 'certname', $target],
                    ],
            ]])
        }

        if $sink.size > 0 {
            $target_params = $sink[0]['parameters']

            if $cfnetwork::hosts_locality == 'pool' {
                $target_tls_default = (
                    $cfnetwork::location != $target_params['location']
                    or
                    $cfnetwork::location_pool != $target_params['location_pool']
                )
            } else {
                $target_tls_default = ($cfnetwork::location != $target_params['location'])
            }

            $target_tls = pick_default(
                $tls,
                $target_tls_default
            )

            # Enable unconditionally
            $target_tls_compress = true

            if $target_tls {
                $target_host = $target
                $target_port = $target_params['secure_port']
            } else {
                $target_host = pick( $target_params['listen'], $target )
                $target_port = $target_params['port']
            }

            include cflogsink::client
        } else {
            cf_notify { "cflogsink target '${target}' is unknown, skipping":
                loglevel => warning,
            }
        }
    } else {
        file { '/etc/rsyslog.conf':
            mode    => '0640',
            content => file('cflogsink/rsyslog-default.conf'),
        }
        ~> Exec['cflogsink:rsyslog:refresh']

        file { '/etc/ulogd.conf':
            mode    => '0640',
            content => file('cflogsink/ulogd-local.conf')
        }
        ~> Exec['cflogsink:ulogd:refresh']
    }
}
