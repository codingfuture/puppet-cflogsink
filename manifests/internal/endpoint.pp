#
# Copyright 2019 (c) Andrey Galkin
#


define cflogsink::internal::endpoint(
    String[1] $type,
    String[1] $location,
    String[1] $location_pool,
    Optional[String[1]] $listen,
    Cfnetwork::Port $port,
    Cfnetwork::Port $secure_port,
) {
}
