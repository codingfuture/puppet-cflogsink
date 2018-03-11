#!/bin/bash

set -x

mode=$1
shift

pt="/usr/share/logstash/bin/logstash-plugin"
installed=$($pt list --installed)
res=0

for p in "$@" skip; do
    if [ $p = "skip" ]; then
        continue;
    fi

    n=$(echo $p | cut -d: -f1)
    i=$(echo "${p}:${p}" | cut -d: -f2)

    if ! echo "$installed" | grep -q $n; then
        if [ $mode = 'install' ]; then
            if ! $pt install $i; then
                res=1
            fi
        else
            res=1
        fi
    elif [ $mode = 'install' ] && ! $pt update $i; then
        res=1
    fi
done

exit $res
