# cflogsink

## Description

Centralized logging infrastructure.

What it does:

* Use ElasticSearch+Logstash stack for centralized log sink.
    * Advanced tuning for all cf* modules.
    * Dedicated system log, HTTP access log and firewall logs.
    * Special handling of various log format cases.
    * Optimized storage field.
    * Special handling of known message formats to minimize noise.
    * Automatic error detection in regular log level.
* Reliably real-time message delivery through rsyslog RELP.
* Supports UDP & TCP local receive (suitable for JVM services).
* Heavy duty `/dev/hdlog` skipping systemd.
    * Mostly for HTTP access log and similar.
    * UDP & TCP are also available.
* NetFilter LOG (NFLOG/ULOG) support throug ulogd2


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
