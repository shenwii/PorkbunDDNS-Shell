#!/bin/sh

cd "$(dirname "$0")"
while true; do
    ./PorkbunDDNS.sh
    sleep 60
done
