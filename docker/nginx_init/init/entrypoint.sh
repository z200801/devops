#!/bin/sh

fl1=/usr/share/nginx/html/index.html
if [ -e ${fl1} ]; then sed -i "s/_HOSTNAME_/$(hostname -f)/g" ${fl1}; fi
exec "$@"
