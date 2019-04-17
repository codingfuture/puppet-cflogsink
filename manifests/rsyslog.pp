#
# Copyright 2019 (c) Andrey Galkin
#

class cflogsink::rsyslog(
    String[1] $version = 'latest',
) {
    case $::operatingsystem {
        'Debian': {
            class { 'cflogsink::rsyslog::debianapt': stage => 'setup' }
        }
        'Ubuntu': {
            class { 'cflogsink::rsyslog::ubuntuapt': stage => 'setup' }
        }
        default: { fail("Not supported OS ${::operatingsystem}") }
    }

    package { 'rsyslog':
        ensure => $version,
    }
    package { 'rsyslog-mmutf8fix': }
    ~> Exec['cflogsink:rsyslog:refresh']
}
