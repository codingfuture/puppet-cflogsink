#
# Copyright 2018 (c) Andrey Galkin
#


class cflogsink (
    Cfnetwork::Bindface
        $iface = $cflogsink::defaults::iface,
    Variant[ Boolean, Hash ]
        $server = false,
    Optional[String[1]]
        $target = undef,
    Optional[Boolean]
        $tls = undef,
) inherits cflogsink::defaults {
    include cfsystem

    if $server {
        if $server =~ Hash {
            $server_conf = $server
        } else {
            $server_conf = {}
        }

        $merged_config = merge(
            {
                iface       => $cflogsink::iface,
                type        => 'logstash',
                port        => 2514,
                secure_port => 3514,
                dbaccess    => {
                    cluster => 'logsink',
                },
            },
            $server_conf
        )

        create_resources(
            'cflogsink::endpoint',
            { main => $merged_config }
        )
    }

    if $target {
        if $target == $::facts['fqdn'] and $server {
            $merged_iface = $merged_config['iface']
            $sink = [{
                'parameters' => {
                    'settings_tune' => {
                        'cflogsink' => {
                            'listen'      => $merged_iface ? {
                                'any'   => undef,
                                default => cfnetwork::bind_address($merged_iface),
                            },
                            'port'        => $merged_config['port'],
                            'secure_port' => $merged_config['secure_port'],
                        },
                    },
                    'location' => $cfsystem::location,
                }
            }]
        } else {
            $sink = cfsystem::query([
                'from', 'resources', ['extract', [ 'parameters' ],
                    ['and',
                        ['=', 'type', 'Cflogsink_endpoint'],
                        ['=', 'certname', $target],
                        ['=', 'title', 'main'],
                    ],
            ]])
        }

        if $sink.size > 0 {
            $target_params = $sink[0]['parameters']
            $target_tune = $target_params['settings_tune']['cflogsink']

            $target_host = pick( $target_tune['listen'], $target )
            $target_tls = pick(
                $tls,
                ($cfsystem::location != $target_params['location'])
            )

            if $target_tls {
                $target_port = $target_tune['secure_port']
            } else {
                $target_port = $target_tune['port']
            }

            include cflogsink::client
        } else {
            notify { "cflogsink target '${target}' is unknown, skipping":
                loglevel => warning,
            }
        }
    }
}
