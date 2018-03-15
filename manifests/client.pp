#
# Copyright 2018 (c) Andrey Galkin
#


class cflogsink::client (
    String[1]
        $host = $cflogsink::target_host,
    Cfnetwork::Port
        $port = $cflogsink::target_port,
    Boolean
        $tls = $cflogsink::target_tls,
    Integer[1]
        $timeout = 90,
    Integer[1]
        $conn_timeout = 5,
    Boolean
        $tls_compress = $cflogsink::target_tls_compress,
    Hash
        $tune = {},
) {
    assert_private()

    include cflogsink

    $om_tune = merge(
        {
            'queue.size' => 10000,
            'queue.dequeuebatchsize'  => 1000,
            'queue.maxdiskspace'      => '1g',
            'queue.timeoutenqueue'    => 0,
            'queue.saveonshutdown'    => 'on',
            'queue.type'              => 'FixedArray',
            'action.resumeretrycount' => -1,
            'action.resumeInterval'   => 10,
            #'action.reportSuspensionContinuation' => 'on',
            #'windowSize'              => 1000,
        },
        $tune,
        {
            'queue.filename' => 'logsink',
            'type' => 'omrelp',
            target => $host,
            port => $port,
            'template' => 'RSYSLOG_SyslogProtocol23Format',
            timeout => $timeout,
            'conn.timeout' => $conn_timeout,
            'tls' => $tls ? { true => 'on', default => 'off' },
            'tls.compression' => $tls_compress ? { true => 'on', default => 'off' },
            'tls.authMode' => 'name',
            'tls.permittedPeer' => [ $host ],
            'tls.cacert' => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
            'tls.mycert' => "/etc/puppetlabs/puppet/ssl/certs/${::facts['fqdn']}.pem",
            'tls.myprivkey' => "/etc/puppetlabs/puppet/ssl/private_keys/${::facts['fqdn']}.pem",
        }
    )

    #---
    $queue_size = $om_tune['queue.size']
    $queue_mb = Integer.new( $queue_size / 512 )

    cfsystem_memory_weight { 'cfsystem:logqueue':
        min_mb => $queue_mb,
        max_mb => $queue_mb,
    }

    #---
    cfnetwork::describe_service { 'cfrelp':
        server => "tcp/${port}",
    }
    cfnetwork::client_port { 'any:cfrelp':
        dst => $host,
    }

    #---
    package { 'rsyslog-relp': }
    -> file { '/etc/rsyslog.d':
        ensure  => directory,
        mode    => '0750',
        purge   => true,
        force   => true,
        recurse => true,
    }
    -> file { '/etc/rsyslog.conf':
        mode    => '0640',
        content => epp('cflogsink/rsyslog.conf.epp', {
            tune => $om_tune,
        })
    }
    ~> service { 'rsyslog':
        ensure => running,
        enable => true,
    }

    #---
    Package['ulogd2']
    -> file { '/etc/ulogd.conf':
        mode    => '0640',
        content => file('cflogsink/ulogd-syslog.conf')
    }
    ~> Exec['cflogsink:ulogd:refresh']
}
