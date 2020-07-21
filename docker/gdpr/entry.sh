#!/bin/sh

# start cron
echo "Starting cron"
/usr/sbin/crond -f -l 8
