#
# Copyright 2018-2019 (c) Andrey Galkin
#

class cflogsink::internal::imrelpmodule {
    assert_private()

    file { '/etc/rsyslog.d/00-imrelpmodule.conf':
        ensure  => file,
        mode    => '0640',
        content => file('cflogsink/imrelpmodule.conf'),
    }
    ~> Exec['cflogsink:rsyslog:refresh']
}
