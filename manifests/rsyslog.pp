#
# Copyright 2019 (c) Andrey Galkin
#

class cflogsink::rsyslog(
    String[1] $version = 'latest',
) {
    case $::operatingsystem {
        'Debian': {
            class { 'cflogsink::rsyslog::debianapt': stage => 'cf-apt-setup' }
        }
        'Ubuntu': {
            class { 'cflogsink::rsyslog::ubuntuapt': stage => 'cf-apt-setup' }
        }
        default: { fail("Not supported OS ${::operatingsystem}") }
    }

    package { 'rsyslog':
        ensure => $version,
    }
}
