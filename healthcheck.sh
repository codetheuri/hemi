#!/bin/sh
# Web container (supervisord is PID 1): nginx must answer and reach php-fpm.
# Any other command, e.g. a queue worker sharing this image, is healthy for as
# long as it runs; the container exits (and restarts) when it dies.
if tr '\0' ' ' < /proc/1/cmdline | grep -q supervisord; then
    exec curl -fsS -o /dev/null --max-time 4 http://127.0.0.1:8099/fpm-ping
fi
exit 0
