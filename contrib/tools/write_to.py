#!/usr/bin/python3

"""
This simple tool reads data from stdin and writes them to a file,
carefully *not* overwriting blocks that already have the desired content.

Usage example:

    cd /mnt/backup/mysql
    mysql -Ne "show databases;" | grep -v '_schema$' | while read db ; do
      mysql -Ne "show tables;" "$db" | while read t ; do
        f="$db/$t.db"
        if ! test -f "$f" ; then
            mkdir -p $db
            touch "$f"
        fi
        echo "mysqldump '$db' '$t' | write_to '$f'"
      done
    done | parallel

The effect is that when your tables don't change/ are only appended to,
your files are not overwritten and thus your incremental backups stay
nice and small.
"""

import sys

if len(sys.argv) != 2:
	raise RuntimeError(f"Usage: {sys.argv[0]} destfile")

fpos=0
bs=4096

fi = sys.stdin.buffer
with open(sys.argv[1], "rb+") as fo:
    fo.seek(0)
    while True:
        od=fi.read(bs)
        if not od:
            fo.truncate(fpos)
            break
        nd=fo.read(bs)
        if nd != od:
            fo.seek(fpos)
            fo.write(od)
        fpos += len(od)

