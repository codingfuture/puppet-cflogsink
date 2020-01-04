# (next)
- FIXED: to support access log vport of upper range
- FIXED: to use stable sort for permitted peer list
- CHANGED: increased Logstash startup timeout to 180 seconds

# 1.3.2 (2019-11-13)
- FIXED: Debian librelp0 priority

# 1.3.1 (2019-06-17)
- CHANGED: returned mmutf8fix before Logstash
- FIXED: cflog_* query to handle spaces
- FIXED: workaround for rsyslog 8.1905 segfault
- NEW: 'proxy' mode for cflogsink::endpoint
- NEW: MongoDB message triage support

# 1.3.0 (2019-04-14)
- CHANGED: to terminate RELP in rsyslog for all cases
- CHANGED: got rid of historical cf-apt-update workaround
- FIXED: cflog_{} access to properly show clientip
- FIXED: to use the latest rsyslog for imrelp endpoint (MSGID corruption fix)

# 1.1.0 (2018-12-09)
- CHANGED: updated for Ubuntu 18.04 Bionic support

# 1.0.1 (2018-04-29)
- FIXED: missing module hiera.yaml
- FIXED: multiple logstash instance DB access name conflict
- FIXED: manifest error when logstash is bound to 'local' iface
- FIXED: rsyslog.conf parsing issue logstash endpoint and secure clients

# 0.12.3 (2018-03-24)
- CHANGED: strip of app name & most kv.* fields in firewall logs
- FIXED: to show app name in cflog_* tool
- FIXED: minor Puppet warnings
- FIXED: missing geoip.location field
- FIXED: to use mmutf8fix to workaround some artifacts in imrelp+TLS
- NEW: in/out/blacklist/forward tagging of firewall logs
- NEW: custom elasticsearch templates for each log type

# 0.12.2 (2018-03-19)
- CHANGED: to use cf_notify for warnings

# 0.12.1 (2018-03-15)
Initial release
