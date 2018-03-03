#!/bin/bash

pt="/usr/share/logstash/bin/logstash-plugin"
installed=$($pt list --installed)
res=0

for p in "$@" skip; do
    if [ $p = "skip" ]; then
        continue;
    fi

    if ! echo "$installed" | grep -q $p; then
        $pt install $p
        res=1
    elif ! $pt update $p; then
        res=1
    fi
do

exit $res
