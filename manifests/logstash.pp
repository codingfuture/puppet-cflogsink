#
# Copyright 2018 (c) Andrey Galkin
#


class cflogsink::logstash {
    include cfdb::elasticsearch
    ensure_resource( 'package', 'logstash' )

    service { 'logstash':
        ensure => stopped,
        enable => mask,
    }
}
