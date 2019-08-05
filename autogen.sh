#!/bin/sh


: ln -s /mnt/doc /usr/local/share

/usr/sbin/install-docs -R
/usr/sbin/install-docs -v -c /etc/doc-base/documents/toolmonitor
: /usr/sbin/dwww-index++ -v -l
: /usr/bin/search --config-file /usr/share/dwww/swish++.conf --index-file /var/cache/dwww/dwww.swish++.index -D
