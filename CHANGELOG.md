# (next)
- FIXED: missing module hiera.yaml

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
