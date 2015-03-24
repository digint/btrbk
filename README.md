Introduction
============

btrbk is a backup tool for btrfs subvolumes, taking advantage of btrfs
specific capabilities to create atomic snapshots and transfer them
incrementally to your backup locations.

The source and target locations are specified in a config file. This
allows simple setups on a single machine with locally attached backup
disks, as well as handling more complex scenarios on a server
receiving backups from several hosts via ssh.

Key Features:

- Atomic snapshots
- Incremental backups
- Backups to multiple destinations
- Transfer via ssh
- Configurable retention policy
- Display file changes between two backups

btrbk is intended to be run as a cron job.


Installation
============

btrbk comes as a single executable file (perl script), without the
need of any installation procedures. If you want the package and
man-pages properly installed, follow the instructions below.

Prerequisites
-------------

- [btrfs-progs]: Btrfs filesystem utilities (use "btrfs_progs_compat"
  option for hosts running version prior to v3.17)
- Perl interpreter: probably already installed on your system
- [Date::Calc]: Perl module, probably already installed on your system

  [btrfs-progs]: http://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/
  [Date::Calc]:  http://search.cpan.org/perldoc?Date::Calc


Instructions
------------

First, [download] the newest stable btrbk source.
Unzip the tarball, go to the btrbk directory and type:

    sudo make install

This will install the btrbk executable along with the man-pages and
an example configuration file.

  [download]: http://www.digint.ch/download/btrbk/releases/


Synopsis
========

Please consult the [btrbk man-page] provided with this package for a
full description of the command line options.

  [btrbk man-page]: http://www.digint.ch/btrbk/doc/btrbk.html


Configuration File
==================

Before running `btrbk`, you will need to create a config file. You
might want to take a look at the example configuration file provided
with this package: `btrbk.conf.example`.

When playing around with config-files, it is highly recommended to
check the output using the `dryrun` command before executing the
backups:

    btrbk -c myconfig -v dryrun

This will read all btrfs information on the source/target filesystems
and show what actions would be performed (without writing anything to
the disks).


Example: laptop with usb-disk for backups
-----------------------------------------

In this example, we assume you have a laptop with:

- a disk having a btrfs volume mounted as `/mnt/btr_pool`, containing
  a subvolume `rootfs` for the root filesystem and a subvolume `home`
  for the user data.
- a backup disk having a btrfs volume mounted as `/mnt/btr_backup`,
  containing a subvolume `mylaptop` for the incremental backups.

Retention policy:

- keep snapshots for 14 days (very handy if you are on the road and
  the backup disk is not attached)
- keep monthly backups forever
- keep weekly backups for 10 weeks
- keep daily backups for 20 days

/etc/btrbk/btrbk-mylaptop.conf:

    snapshot_preserve_daily    14
    snapshot_preserve_weekly   0
    snapshot_preserve_monthly  0

    target_preserve_daily      20
    target_preserve_weekly     10
    target_preserve_monthly    all

    snapshot_dir               btrbk_snapshots

    volume /mnt/btr_pool
      subvolume  rootfs
        target send-receive    /mnt/btr_backup/mylaptop

      subvolume  home
        target send-receive    /mnt/btr_backup/mylaptop


/etc/cron.daily/btrbk:

    #!/bin/bash
    /usr/sbin/btrbk -c /etc/btrbk/btrbk-mylaptop.conf run


- This will create snapshots on a daily basis:
  - `/mnt/btr_pool/btrbk_snapshots/rootfs.YYYYMMDD`
  - `/mnt/btr_pool/btrbk_snapshots/home.YYYYMMDD`
- And create incremental backups in:
  - `/mnt/btr_backup/mylaptop/rootfs.YYYYMMDD`
  - `/mnt/btr_backup/mylaptop/home.YYYYMMDD`

If you want the snapshots to be created even if the backup disk is not
attached (when you're on the road), simply add the following line to
the config:

    snapshot_create_always     yes


Example: host-initiated backup on fileserver
--------------------------------------------

Lets say you have a fileserver at "myserver.mydomain.com" where you
want to create backups of your laptop disk, the config would look like
this:

    ssh_identity               /etc/btrbk/ssh/id_rsa

    volume /mnt/btr_pool
      subvolume  rootfs
        target send-receive    /mnt/btr_backup/mylaptop
        target send-receive    ssh://myserver.mydomain.com/mnt/btr_backup/mylaptop

In addition to the backups on your local usb-disk mounted at
`/mnt/btr_backup/mylaptop`, incremental backups would also be pushed
to `myserver.mydomain.com`.


Example: fileserver-initiated backups from several hosts
--------------------------------------------------------

If you're a sysadmin and want to trigger backups directly from your
fileserver, the config would be something like:

    ssh_identity               /etc/btrbk/ssh/id_rsa

    volume ssh://alpha.mydomain.com/mnt/btr_pool
      subvolume rootfs
        target send-receive    /mnt/btr_backup/alpha

      subvolume home
        target send-receive    /mnt/btr_backup/alpha

    volume ssh://beta.mydomain.com/mnt/btr_pool
      subvolume rootfs
        target send-receive    /mnt/btr_backup/beta

      subvolume dbdata
        target send-receive    /mnt/btr_backup/beta

This will pull backups from alpha/beta.mydomain.com and locally create:

- `/mnt/btr_backup/alpha/rootfs.YYYYMMDD`
- `/mnt/btr_backup/alpha/home.YYYYMMDD`
- `/mnt/btr_backup/beta/rootfs.YYYYMMDD`
- `/mnt/btr_backup/beta/dbdata.YYYYMMDD`


Setting up SSH
==============

Since btrbk needs root access on the remote side, it is *very
advisable* to take all security precautions you can. Usually backups
are generated periodically without user interaction, so it is not
possible to protect your ssh key with a password. The steps below
shall give you hints on how to secure your ssh server for a backup
scenario.

btrbk provides a little shell script called "ssh_filter_btrbk.sh",
which only allows sane calls to the /sbin/btrfs command needed for
snapshot creation and send/receive operations. This is how it is used
with ssh:

**Step 1** (client): Create a ssh key dedicated to btrbk, without password protection:

    ssh-keygen -t rsa -b 2048 -f /etc/btrbk/ssh/id_rsa -C btrbk@mydomain.com -N ""

**Step 2** (server): Copy the "ssh_filter_btrbk.sh" from the btrbk project to "/root/".

**Step 3** (server): Add contents of the public key
  (/etc/btrbk/ssh/id_rsa.pub) to "/root/.ssh/authorized_keys",
  restricting access from a single host:

    from="192.168.0.42",command="/root/ssh_filter_btrbk.sh" ssh-rsa AAAAB3NzaC1...hwumXFRQBL btrbk@mydomain.com

Now your ssh server allows connections only from 192.168.0.42, and
will only execute commands needed by btrbk. Note that the btrbk
executable is not needed on the remote side, but you will need
"/sbin/btrfs" from the btrfs-progs package.


Development
===========

Source Code Repository
----------------------

The source code for btrbk is managed using Git. Check out the source
like this:

    git clone git://dev.tty0.ch/btrbk.git


How to Contribute
-----------------

Your contributions are welcome!

If you would like to contribute or found bugs:

- visit the [btrbk project page on GitHub] and use the [issues
  tracker] there
- talk to us on Freenode in #btrbk
- contact the author via email (the email address can be found in the
  sources)

Any feedback is appreciated!

  [btrbk project page on GitHub]: http://github.com/digint/btrbk
  [issues tracker]: http://github.com/digint/btrbk/issues


License
=======

btrbk is free software, available under the [GNU General Public
License, Version 3][GPLv3].

  [GPLv3]: http://www.gnu.org/licenses/gpl.html

