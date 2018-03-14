#
# Copyright 2018 (c) Andrey Galkin
#

class cflogsink::netsyslog {
    include cfnetwork
    include cflogsink
    include cflogsink::netmodules

    cfnetwork::describe_service { 'netsyslog':
        server => [
            'tcp/514',
            'udp/514',
        ]
    }
    cfnetwork::service_port { 'local:netsyslog': }

    file { '/etc/rsyslog.d/05-netsyslog.conf':
        ensure  => file,
        mode    => '0640',
        content => file('cflogsink/netsyslog.conf'),
    }
    ~> Exec['cflogsink:rsyslog:refresh']
}
