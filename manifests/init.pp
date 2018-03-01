#
# Copyright 2018 (c) Andrey Galkin
#


class cflogsink (
    Cfnetwork::Bindface
        $iface = $cflogsink::defaults::iface,
    Variant[ Boolean, Hash ]
        $server = false,
) inherits cflogsink::defaults {
    if $server {
        if $server =~ Hash {
            $server_conf = $server
        } else {
            $server_conf = {}
        }

        create_resources(
            'cflogsink::endpoint',
            { default => $server_conf },
            {
                type     => 'logstash',
                port     => 2514,
                ssl_port => 3514,
                dbaccess => {
                    cluster => 'logsink',
                },
            }
        )
    }
}
