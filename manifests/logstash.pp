#
# Copyright 2018 (c) Andrey Galkin
#


class cflogsink::logstash (
    Array[ String[1] ] $plugins = [],
) {
    include cfdb::elasticsearch
    ensure_resource( 'package', 'logstash' )

    file { '/etc/systemd/system/logstash.service':
        ensure => link,
        target => '/dev/null',
    } ->
    service { 'logstash':
        ensure  => stopped,
        enable  => mask,
        require => Package['logstash'],
    }

    #---
    $all_plugins = $plugins + [
        'logstash-input-relp:input-plugin-relp',
        #'',
    ]

    $plugin_installer = "/usr/share/logstash/bin/logstash-plugin-installer"

    file { $plugin_installer:
        mode    => '0700',
        content => file( 'cflogsink/logstash_plugin_installer.sh' ),
    } ->
    exec { "Installing LogStash plugins":
        command => "${plugin_installer} install ${all_plugins.join(' ')}",
        unless  => "${plugin_installer} check ${all_plugins.join(' ')}",
    }
}
