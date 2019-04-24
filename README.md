Introduction
============

btrbk is a backup tool for btrfs subvolumes, taking advantage of btrfs
specific capabilities to create atomic snapshots and transfer them
incrementally to your backup locations.

The source and target locations are specified in a config file, which
allows to easily configure simple scenarios like "laptop with locally
attached backup disks", as well as more complex ones, e.g. "server
receiving backups from several hosts via ssh, with different retention
policy".

Key Features:

  * Atomic snapshots
  * Incremental backups
  * Configurable retention policy
  * Backups to multiple destinations
  * Transfer via ssh
  * Resume of backups (if backup target was not reachable for a while)
  * Encrypted backups to non-btrfs destinations
  * Wildcard subvolumes (useful for docker and lxc containers)
  * Transaction log
  * Comprehensive list and statistics output
  * Resolve and trace btrfs parent-child and received-from relationships
  * Display file changes between two backups

btrbk is designed to run as a cron job for triggering periodic
snapshots and backups, as well as from the command line (e.g. for
instantly creating additional snapshots).


Installation
============

Btrbk is a single perl script, and does not require any special
installation procedures or libraries. Simply download the latest
[btrbk source tarball] and run the "btrbk" executable.

For more information, read the [installation documentation].

  [btrbk source tarball]: https://digint.ch/download/btrbk/releases/
  [installation documentation]: doc/install.md


### Prerequisites

  * [btrfs-progs]: Btrfs filesystem utilities >= v4.12
  * [Perl interpreter]: Probably already installed on your system
  * [OpenSSH]: If you want to transfer backups from/to remote locations
  * [Pipe Viewer]: If you want rate limiting and progress bars

  [btrfs-progs]: https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/
  [Perl interpreter]: https://www.perl.org
  [OpenSSH]: https://www.openssh.org
  [Pipe Viewer]: https://www.ivarch.com/programs/pv.shtml


Synopsis
========

Please consult the [btrbk(1)] man-page provided with this package for
a full description of the command line options.

  [btrbk(1)]: https://digint.ch/btrbk/doc/btrbk.1.html


Configuration File
==================

Before running `btrbk`, you will need to create a configuration
file. You might want to take a look at `btrbk.conf.example` provided
with this package. For a detailed description, please consult the
[btrbk.conf(5)] man-page.

When playing around with config-files, it is highly recommended to
check the output using the `dryrun` command before executing the
backups:

    btrbk -c /path/to/myconfig -v dryrun

This will read all btrfs information on the source/target filesystems
and show what actions would be performed (without writing anything to
the disks).

  [btrbk.conf(5)]: https://digint.ch/btrbk/doc/btrbk.conf.5.html


Example: laptop with usb-disk for backups
-----------------------------------------

In this example, we assume you have a laptop with:

  * a disk having a btrfs root subvolume (subvolid=5) mounted on
    `/mnt/btr_pool`, containing a subvolume `rootfs` for the root
    filesystem (i.e. mounted on `/`) and a subvolume `home` for the
    user data,
  * a directory or subvolume `/mnt/btr_pool/btrbk_snapshots` which
    will hold the btrbk snapshots,
  * a backup disk having a btrfs volume mounted as `/mnt/btr_backup`,
    containing a subvolume or directory `mylaptop` for the incremental
    backups.

Retention policy:

  * keep all snapshots for 2 days, no matter how frequently you (or
    your cron-job) run btrbk
  * keep daily snapshots for 14 days (very handy if you are on
    the road and the backup disk is not attached)
  * keep monthly backups forever
  * keep weekly backups for 10 weeks
  * keep daily backups for 20 days

/etc/btrbk/btrbk-mylaptop.conf:

    snapshot_preserve_min       2d
    snapshot_preserve          14d

    target_preserve_min        no
    target_preserve            20d 10w *m

    snapshot_dir               btrbk_snapshots

    volume /mnt/btr_pool
      target /mnt/btr_backup/mylaptop
      subvolume rootfs
      subvolume home
      [...]


/etc/cron.daily/btrbk:

    #!/bin/sh
    exec /usr/sbin/btrbk -q -c /etc/btrbk/btrbk-mylaptop.conf run


  * This will create snapshots on a daily basis:
    * `/mnt/btr_pool/btrbk_snapshots/rootfs.YYYYMMDD`
    * `/mnt/btr_pool/btrbk_snapshots/home.YYYYMMDD`
  * And create incremental backups in:
    * `/mnt/btr_backup/mylaptop/rootfs.YYYYMMDD`
    * `/mnt/btr_backup/mylaptop/home.YYYYMMDD`

If you want the snapshots to be created only if the backup disk is
attached, simply add the following line to the config:

    snapshot_create            ondemand

For a quick additional snapshot of your home, run:

    # btrbk snapshot home


Example: host-initiated backup on fileserver
--------------------------------------------

Let's say you have a fileserver at "myserver.mydomain.com" where you
want to create backups of your laptop disk, the config would look like
this:

    ssh_identity               /etc/btrbk/ssh/id_rsa

    volume /mnt/btr_pool
      subvolume rootfs
        target /mnt/btr_backup/mylaptop
        target ssh://myserver.mydomain.com/mnt/btr_backup/mylaptop

In addition to the backups on your local usb-disk mounted at
`/mnt/btr_backup/mylaptop`, incremental backups would also be pushed
to `myserver.mydomain.com`.


Example: fileserver-initiated backups from several hosts
--------------------------------------------------------

If you're a sysadmin and want to trigger backups directly from your
fileserver, the config would be something like:

    ssh_identity               /etc/btrbk/ssh/id_rsa

    volume ssh://alpha.mydomain.com/mnt/btr_pool
      target /mnt/btr_backup/alpha
      subvolume rootfs
      subvolume home

    volume ssh://beta.mydomain.com/mnt/btr_pool
      target /mnt/btr_backup/beta
      subvolume rootfs
      subvolume dbdata

This will pull backups from alpha/beta.mydomain.com and locally
create:

  * `/mnt/btr_backup/alpha/rootfs.YYYYMMDD`
  * `/mnt/btr_backup/alpha/home.YYYYMMDD`
  * `/mnt/btr_backup/beta/rootfs.YYYYMMDD`
  * `/mnt/btr_backup/beta/dbdata.YYYYMMDD`


Example: local time-machine (hourly snapshots)
----------------------------------------------

If all you want is to create snapshots of your home directory on a
regular basis:

/etc/btrbk/btrbk.conf:

    timestamp_format        long
    snapshot_preserve_min   18h
    snapshot_preserve       48h 20d 6m

    volume /mnt/btr_pool
      snapshot_dir btrbk_snapshots
      subvolume home

/etc/cron.hourly/btrbk:

    #!/bin/sh
    exec /usr/sbin/btrbk -q run

Note that you can run btrbk more than once an hour, e.g. by calling
`sudo btrbk run` from the command line. With this setup, all those
extra snapshots will be kept for 18 hours.


Example: multiple btrbk instances
---------------------------------

Let's say we have a host (at 192.168.0.42) running btrbk with the
setup of the time-machine example above, and we need a backup server
to only fetch the snapshots.

/etc/btrbk/btrbk.conf (on backup server):

    target_preserve_min        no
    target_preserve            0d 10w *m

    volume ssh://192.168.0.42/mnt/btr_pool
      subvolume home
        snapshot_dir           btrbk_snapshots
        snapshot_preserve_min  all
        snapshot_create        no

        target /mnt/btr_backup/my-laptop.com

If the server runs btrbk with this config, 10 weeklies and all
monthlies are received from 192.168.0.42. The source filesystem is
never altered because of `snapshot_preserve_min all`.


Example: virtual machine setup
------------------------------

Common virtual machine setups have multiple volume sections with same
host, but distinct port numbers for each machine.

/etc/btrbk/btrbk.conf:

    # This propagates to all subvolume sections:
    target /mnt/btr_backup/

    volume ssh://localhost:2201/mnt/btr_pool
      group vm vm01
      subvolume home
        snapshot_name vm01-home
      subvolume data
        snapshot_name vm01-data

    volume ssh://localhost:2202/mnt/btr_pool
      group vm vm02
      subvolume home
        snapshot_name vm02-home

    volume ssh://localhost:2203/mnt/btr_pool
      [...]

This will create `/mnt/btr_backup/vm[NN]-home`, `vm[NN]-data`, ...

Note that btrbk holds a single reference to every btrfs filesystem
tree, regarding UUID's as "globally unique". If the configured
subvolumes point to the same filesystem on different machines (ports),
you will see log lines like this when running `btrbk -v`:

```
Assuming same filesystem: "ssh://localhost:2201/dev/sda1", "ssh://localhost:2202/dev/sda1"
```


Example: backup from non-btrfs source
-------------------------------------

First create a btrfs subvolume on the backup server:

    # btrfs subvolume create /mnt/btr_backup/myhost_sync

In your daily cron script, prior to running btrbk, sync your source to
`myhost_sync`, something like:

    rsync -a --inplace --delete -e ssh myhost.mydomain.com:/data/ /mnt/btr_backup/myhost_sync/

Then run btrbk, with myhost_sync configured *without any targets* as
follows:

    volume /mnt/btr_backup
      subvolume myhost_sync
        snapshot_name           myhost

        snapshot_preserve_min   latest
        snapshot_preserve       14d 20w *m

This will produce daily snapshots `/mnt/btr_backup/myhost.20150101`,
with retention as defined with the snapshot_preserve option.

Note that the provided script: "contrib/cron/btrbk-mail" has support
for this!


Example: encrypted backup to non-btrfs target
---------------------------------------------

If your backup server does not support btrfs, you can send your
subvolumes to a raw file.

This is an _experimental_ feature: btrbk supports "raw" targets,
meaning that similar to the "send-receive" target the btrfs subvolume
is being sent using `btrfs send` (mirroring filesystem level data),
but instead of instantly being received (`btrfs receive`) by the
target filesystem, it is being redirected to a file, optionally
compressed and piped through GnuPG.

/etc/btrbk/btrbk.conf:

    raw_target_compress   xz
    raw_target_encrypt    gpg
    gpg_keyring           /etc/btrbk/gpg/pubring.gpg
    gpg_recipient         btrbk@mydomain.com

    volume /mnt/btr_pool
      subvolume home
        target raw ssh://cloud.example.com/backup
          ssh_user  btrbk
          # incremental  no

This will create a GnuPG encrypted, compressed files on the target
host. For each backup, two files are created:

  * `/backup/home.YYYYMMDD.btrfs.xz.gpg`: main data file containing
    the btrfs send-stream,
  * `/backup/home.YYYYMMDD.btrfs.xz.gpg.info`: sidecar file containing
    metadata used by btrbk.

I you are using raw _incremental_ backups, please make sure you
understand the implications (see [btrbk.conf(5)], TARGET TYPES).


Setting up SSH
==============

Since btrbk needs root access, it is *very advisable* to take all the
security precautions you can. In most cases backups are generated
periodically without user interaction, so it is not possible to
protect your ssh key with a password. The steps below will give you
hints on how to secure your ssh server for a backup scenario. Note
that the `btrbk` executable is not needed on the remote side, but you
will need the `btrfs` executable from the [btrfs-progs] package.


### Step 1: Create SSH keypair

On the client side, create a ssh key dedicated to btrbk, without
password protection:

    ssh-keygen -t rsa -b 2048 -f /etc/btrbk/ssh/id_rsa -C btrbk@mydomain.com -N ""

The content of the public key (/etc/btrbk/ssh/id_rsa.pub) is used for
authentication in "authorized_keys" on the server side (see [sshd(8)]
for details).


### Step 2 (option): root login restricted by "ssh_filter_btrbk.sh"

Btrbk comes with a shell script "ssh_filter_btrbk.sh", which restricts
ssh access to sane calls to the "btrfs" command needed for snapshot
creation and send/receive operations (see [ssh_filter_btrbk(1)]).

Copy "ssh_filter_btrbk.sh" to "/backup/scripts/", and configure sshd
to run it whenever the key is used for authentication. Example
"/root/.ssh/authorized_keys":

    # example backup source (also allowing deletion of old snapshots)
    command="/backup/scripts/ssh_filter_btrbk.sh -l --source --delete" <pubkey>...

    # example backup target (also allowing deletion of old snapshots)
    command="/backup/scripts/ssh_filter_btrbk.sh -l --target --delete" <pubkey>...

    # example fetch-only backup source (snapshot_preserve_min=all, snapshot_create=no),
    # restricted to subvolumes within /home or /data
    command="/backup/scripts/ssh_filter_btrbk.sh -l --send -p /home -p /data" <pubkey>...


### Step 2 (option): dedicated user login, using different backend

Create a user dedicated to btrbk and add the public key to
"/home/btrbk/.ssh/authorized_keys". In "btrbk.conf", choose either:

 * `backend btrfs-progs-btrbk` to use separated binaries with elevated
   privileges (suid or fscaps) instead of the "btrfs" command (see
   [btrfs-progs-btrbk]).

 * `backend btrfs-progs-sudo`, configure "/etc/sudoers" and add the
   `ssh_filter_btrbk.sh --sudo` option.


### Further considerations

You might also want to restrict ssh access to a static IP address
within your network:

    from="192.168.0.42",command=... <pubkey>...

For even more security, set up a chroot environment in
"/etc/ssh/sshd_config" (see [sshd_config(5)]).


  [ssh_filter_btrbk(1)]: https://digint.ch/btrbk/doc/ssh_filter_btrbk.1.html
  [sshd(8)]: https://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man8/sshd.8
  [sshd_config(5)]: https://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man5/sshd_config
  [btrfs-progs-btrbk]: https://github.com/digint/btrfs-progs-btrbk


Restoring Backups
=================

btrbk does not provide any mechanism to restore your backups, this has
to be done manually. In the examples below, we assume that you have a
btrfs volume mounted at `/mnt/btr_pool`, and the subvolume you want to
have restored is at `/mnt/btr_pool/data`.

**Important**: don't use `btrfs property set` to make a subvolume
read-write after restoring. This is a low-level command, and leaves
"Received UUID" in a false state which causes btrbk to fail on
subsequent incremental backups. Instead, use `btrfs subvolume
snapshot` (without `-r` flag) as described below.


Example: Restore a Snapshot
-----------------------------

First, pick a snapshot to be restored:

    btrbk list snapshots

From the list, pick the snapshot you want to restore. Let's say it's
`/mnt/btr_pool/_btrbk_snap/data.20150101`.

If the broken subvolume is still present, move it away:

    mv /mnt/btr_pool/data /mnt/btr_pool/data.BROKEN

Now restore the snapshot:

    btrfs subvolume snapshot /mnt/btr_pool/_btrbk_snap/data.20150101 /mnt/btr_pool/data

That's it; your `data` subvolume is restored. If everything went fine,
it's time to nuke the broken subvolume:

    btrfs subvolume delete /mnt/btr_pool/data.BROKEN


Example: Restore a Backup
-------------------------

First, pick a backup to be restored:

    btrbk list backups

From the list, pick the backup you want to restore. Let's say it's
`/mnt/btr_backup/data.20150101`.

If the broken subvolume is still present, move it away:

    mv /mnt/btr_pool/data /mnt/btr_pool/data.BROKEN

Now restore the backup:

    btrfs send /mnt/btr_backup/data.20150101 | btrfs receive /mnt/btr_pool/
    btrfs subvolume snapshot /mnt/btr_pool/data.20150101 /mnt/btr_pool/data
    btrfs subvolume delete /mnt/btr_pool/data.20150101

Alternatively, if you're restoring data on a remote host, do something
like this:

    btrfs send /mnt/btr_backup/data.20150101 | ssh root@my-remote-host.com btrfs receive /mnt/btr_pool/

Hint: If you still have common snapshot / backup pairs (i.e. both
"snapshot_subvol" and "target_subvol" are listed) consider sending the
backup incrementally by specifying a parent subvolume:

    btrfs send -p /mnt/btr_backup/<parent-subvolume> [...]

This allows btrbk to continue using the parent subvolume for
incremental backups later.

If everything went fine, nuke the broken subvolume:

    btrfs subvolume delete /mnt/btr_pool/data.BROKEN


FAQ
===

Make sure to also read the [btrbk FAQ page](doc/FAQ.md).
Help improve it by asking!


Donate
======

So btrbk saved your day?

I will definitively continue developing btrbk for free, but if you
want to support me you can do so:

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WFQSSCD9GNM4S)


Development
===========

Source Code Repository
----------------------

The source code for btrbk is managed using Git.

Official repository:

    git clone https://dev.tty0.ch/btrbk.git

Mirror on GitHub:

    git clone https://github.com/digint/btrbk.git


How to Contribute
-----------------

Your contributions are welcome!

If you would like to contribute or have found bugs:

  * Visit the [btrbk project page on GitHub] and use the
    [issues tracker] there.
  * Talk to us on Freenode in `#btrbk`.
  * Contact the author via email (the email address can be found in
    the sources).

Any feedback is appreciated!

  [btrbk project page on GitHub]: https://github.com/digint/btrbk
  [issues tracker]: https://github.com/digint/btrbk/issues


License
=======

btrbk is free software, available under the [GNU General Public
License, Version 3 or later][GPL-3.0-or-later].

  [GPL-3.0-or-later]: https://www.gnu.org/licenses/gpl.html
