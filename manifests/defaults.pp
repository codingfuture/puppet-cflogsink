#
# Copyright 2018 (c) Andrey Galkin
#


class cflogsink::defaults {
    include cfsystem

    $iface = $cfsystem::service_face
}
