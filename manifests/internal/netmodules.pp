#
# Copyright 2018 (c) Andrey Galkin
#

class cflogsink::internal::netmodules {
    assert_private()

    file { '/etc/rsyslog.d/00-netmodules.conf':
        ensure  => file,
        mode    => '0640',
        content => file('cflogsink/netmodules.conf'),
    }
    ~> Exec['cflogsink:rsyslog:refresh']
}
