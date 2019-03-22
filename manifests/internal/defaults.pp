#
# Copyright 2018-2019 (c) Andrey Galkin
#


class cflogsink::internal::defaults {
    include cfsystem

    $iface = $cfsystem::service_face
}
