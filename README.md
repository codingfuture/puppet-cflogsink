# cflogsink

## Description

Centralized logging infrastructure.

What it does:

* Use ElasticSearch+Logstash stack for centralized log sink.
    * Advanced tuning for all cf* modules.
    * Dedicated strictly types system log, HTTP access log and firewall log indexes.
    * Special handling of various log format cases.
    * Optimized storage field.
    * Special handling of known message formats to minimize noise.
    * Automatic error detection in regular log level.
* Support for custom Logstash endpoint for special purposes.
* Reliably real-time message delivery through rsyslog RELP.
* Supports UDP & TCP local receive (suitable for JVM services).
* Heavy duty `/dev/hdlog` skipping systemd.
    * Mostly for HTTP access log and similar.
    * UDP & TCP are also available.
* NetFilter LOG (NFLOG/ULOG) support through ulogd2
* CLI ElastciSearch log viewer `cflog`:
    * Help for cases when Kibana gets broken or not available
    * Mimics ordinary log file output
    * Supports simple queries for filtering
* Kibana installation is provided in [cfwebapp](https://forge.puppet.com/codingfuture/cfwebapp) module.

## Technical Support

* [Example configuration](https://github.com/codingfuture/puppet-test)
* Free & Commercial support: [support@codingfuture.net](mailto:support@codingfuture.net)

## Setup

Please use [librarian-puppet](https://rubygems.org/gems/librarian-puppet/) or
[cfpuppetserver module](https://forge.puppetlabs.com/codingfuture/cfpuppetserver) to deal with dependencies.

There is a known r10k issue [RK-3](https://tickets.puppetlabs.com/browse/RK-3) which prevents
automatic dependencies of dependencies installation.

## Examples

Please check [codingufuture/puppet-test](https://github.com/codingfuture/puppet-test) for
example of a complete infrastructure configuration and Vagrant provisioning.

## Implicitly created resources

```yaml
cfnetwork::describe_services:
    # if $cflogsink::repo_proxy
    'aptproxy':
        server: "tcp/${proxy_port}"
    # if cflogsink::netsyslog
    netsyslog:
        server:
            - 'tcp/514'
            - 'udp/514'
    # if cflogsink::hdsyslog
    hdsyslog:
        server:
            - 'tcp/${port}'
            - 'udp/${port}'
cfnetwork::service_ports:
    # if cflogsink::netsyslog
    'local:netsyslog': {}
    # if cflogsink::hdsyslog
    'local:hdsyslog': {}
cfnetwork::client_ports:
```

## Class parameters

## `cflogsink` class

The main Hiera-friendly configuration class

* `$iface = $cfsystem::service_face` - interface for server instance to listen.
* `$server = false` - `cflogsink::endpoint` option hash or just `true` to enable `main` logsink endpoint.
* `$target = false` - `cflogsink::client` option hash or just string with hostname of centralized log sink.
* `$tls = undef` - controls if connection to target has to be secured via TLS.

## `cflogsink::netsyslog` class

Adds local UDP & TCP syslog sockets for regular use of JVM and other services which
do not support UNIX domain socket.

## `cflogsink::hdsyslog` class

Heavy Duty syslog provided through /dev/hdlog. Sutiable for HTTP access logs and similar load.
This functionality skips systemd and is designed to work in pair with cflogsink::client.

* `$tune = {}` - allow rsyslog ruleset queue tuning
* `$port = 515` - port to use for UDP & TCP

## `cflogsink::client` class

Centralized logging client setup.

* `$host = ...` - auto-configured based on `cflogsink::target`.
* `$port = ...` - auto-configured based on `cflogsink::target `main` endpoint.
* `$tls = ...` - auto-configured based on explicit `cflogsink::tls`. Otherwise, checks if location
    mismatch between client and target.
* `$timeout = 90` - session timeout.
* `$conn_timeout = 5` - connection timeout.
* `tls_compress = ..` - auto-configured.
* `$tune = {}` - fine tune rsyslog:
    - `queue.*` - go to `main_queue()`
    - rest goes into `action()` config

## `cflogsink::endpoint` type

Configure log sink endpoint.

* `$type = 'logstash'` - type of endpoint, only logstash is supported so far.
* `$config = undef` - override the default configuration template.
* `$memory_weight = 100` - memory weight for automatic distribution.
* `$memory_max = undef` - max memory to use in MB.
* `$cpu_weight = 100` - CPU weight for scheduling.
* `$io_weight = 100` - IO weight for scheduling.
* `$settings_tune = {}` - fine tune generated configuration.
* `$iface = $cflogsink::iface` - interface to bind.
* `$port = undef` - port to use for insecure connections.
* `$secure_port = undef` - port to use for TLS connections.
* `$dbaccess = undef` - database acccess (e.g. Elasticsearch for Logstash).
* `$extra_clients = []` - extra list of insecure clients (for cfnetwork::ipset).
* `$extra_secure_clients = []` - extra list of secure clients (for cfnetwork::ipset).

# `cflog_${title}` CLI tool

The tool is created per `cflogsink::endpoint` instance. Below is example for the default one.
All output goes to `less` which scrolls to end by default.

It's essential in case of emergency when Kibana output is not available.

By default size limit is 10000 messages. They are counted from the newest. Amount of skipped
messages can be seet with `<from>` argument.

Day, month and year selection can be done through index name.

Usage:

    Usage: cflog_main <index> [<query> [<from> [<size>]]]
    Known indexes: 'access', 'fw' and 'log'

Lookup latest logs for all hosts:

    $ cflog_main log
    ...
    2018-03-15T16:04:05.824Z        web.example.com notice  Received disconnect from 10.0.2.2 port 39233:11: disconnected by user
    2018-03-15T16:04:05.824Z        web.example.com notice  Disconnected from 10.0.2.2 port 39233
    2018-03-15T16:04:05.825Z        web.example.com notice  pam_unix(sshd:session): session closed for user vagrant
    ....
    2018-03-15T16:04:13.802Z        web2.example.com        notice  Disconnected from 10.0.2.2 port 53173
    2018-03-15T16:04:13.803Z        web2.example.com        notice  pam_unix(sshd:session): session closed for user vagrant
    ...
    2018-03-15T16:04:56.815Z        puppet.example.com      notice  rexec line 25: Deprecated option RhostsRSAAuthentication
    ...

Lookup firewall logs for particular month and host:

    $ cflog_main fw-2018.03 host:maint.example.com
    ... 
    2018-03-15T16:10:11.397Z        maint.example.com       OUT-unknown: IN= OUT=eth1 MAC= SRC=:: DST=ff02::16 LEN=96 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICMPv6 TYPE=143 CODE=0
    2018-03-15T16:10:11.397Z        maint.example.com       OUT-unknown: IN= OUT=eth1 MAC= SRC=:: DST=ff02::16 LEN=96 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICMPv6 TYPE=143 CODE=0
    2018-03-15T16:10:11.397Z        maint.example.com       OUT-unknown: IN= OUT=eth1 MAC= SRC=:: DST=ff02::16 LEN=76 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICMPv6 TYPE=143 CODE=0
    2018-03-15T16:10:11.397Z        maint.example.com       OUT-unknown: IN= OUT=eth1 MAC= SRC=:: DST=ff02::16 LEN=76 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICMPv6 TYPE=143 CODE=0
    2018-03-15T16:10:11.397Z        maint.example.com       OUT-vagrant: IN= OUT=eth0 MAC= SRC=:: DST=ff02::16 LEN=76 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICMPv6 TYPE=143 CODE=0
    2018-03-15T16:10:11.397Z        maint.example.com       OUT-vagrant: IN= OUT=eth0 MAC= SRC=:: DST=ff02::16 LEN=76 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICMPv6 TYPE=143 CODE=0
    2018-03-15T16:10:13.125Z        maint.example.com       OUT-vagrant: IN= OUT=eth0 MAC= SRC=fe80::a00:27ff:fe8d:c04d DST=ff02::16 LEN=76 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=
    2018-03-15T16:10:13.125Z        maint.example.com       OUT-main: IN= OUT=eth1 MAC= SRC=fe80::a00:27ff:fea8:e56a DST=ff02::16 LEN=96 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICM
    2018-03-15T16:10:13.125Z        maint.example.com       OUT-vagrant: IN= OUT=eth0 MAC= SRC=fe80::a00:27ff:fe8d:c04d DST=ff02::16 LEN=76 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=
    2018-03-15T16:10:13.125Z        maint.example.com       OUT-main: IN= OUT=eth1 MAC= SRC=fe80::a00:27ff:fea8:e56a DST=ff02::16 LEN=96 TC=0 HOPLIMIT=1 FLOWLBL=0 PROTO=ICM

Lookup access logs for particular application:

    $ cflog_main access app:cfpuppetserver
    ...
    2018-03-15T16:07:44.803Z                200     130     puppetback.example.com  GET /puppet/v3/node/db.example.com?environment=production&configured_environment=product
    2018-03-15T16:07:44.941Z                200     36      puppetback.example.com  GET /puppet/v3/file_metadatas/pluginfacts?environment=production&links=follow&recurse=tr
    2018-03-15T16:07:45.885Z                200     729     puppetback.example.com  GET /puppet/v3/file_metadatas/plugins?environment=production&links=follow&recurse=true&s
    2018-03-15T16:07:46.175Z                200     24      puppetback.example.com  GET /puppet/v3/file_content/plugins/puppet/provider/cflogsink_endpoint/cflogsink.rb?envi
    2018-03-15T16:07:46.230Z                200     24      puppetback.example.com  GET /puppet/v3/file_content/plugins/puppet/provider/cflogsink_endpoint/cflogsink.rb?envi
    2018-03-15T16:07:46.357Z                200     27      puppetback.example.com  GET /puppet/v3/file_metadatas/locales?environment=production&links=follow&recurse=true&s
    2018-03-15T16:08:10.808Z                200     23096   puppetback.example.com  POST /puppet/v3/catalog/db.example.com?environment=production
    2018-03-15T16:08:29.039Z                200     2467    puppetback.example.com  PUT /puppet/v3/report/db.example.com?environment=production&
