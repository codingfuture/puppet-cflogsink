
class cflogsink::client (
    String[1]
        $host = $cflogsink::target_host,
    Cfnetwork::Port
        $port = $cflogsink::target_port,
    Boolean
        $tls = $cflogsink::target_tls,
    Integer[1]
        $timeout = 600,
    Integer[1]
        $conn_timeout = 5,
    Boolean
        $tls_compress = true,
) {
    include cflogsink
}
