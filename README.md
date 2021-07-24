Introduction
============

Btrbk is a backup tool for btrfs subvolumes, taking advantage of btrfs
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
  * Flexible retention policy
  * Backups to multiple destinations
  * Transfer via ssh
  * Resume backups (for removable and mobile devices)
  * Archive to offline storage
  * Encrypted backups to non-btrfs storage
  * Wildcard subvolumes (useful for docker and lxc containers)
  * Transaction log
  * Comprehensive list and statistics output
  * Resolve and trace btrfs parent-child and received-from relationships
  * List file changes between backups
  * Calculate accurate disk space usage based on block regions

Btrbk is designed to run as a cron job for triggering periodic
snapshots and backups, as well as from the command line (e.g. for
instantly creating additional snapshots).


Installation
============

Btrbk is a single perl script, and does not require any special
installation procedures or libraries. Download the latest [btrbk
source tarball], or try latest master:

    wget https://raw.githubusercontent.com/digint/btrbk/master/btrbk
    chmod +x btrbk
    sudo ./btrbk ls /

For more information, read the [installation documentation].

  [btrbk source tarball]: https://digint.ch/download/btrbk/releases/
  [installation documentation]: doc/install.md


### Prerequisites

  * [btrfs-progs]: Btrfs filesystem utilities >= v4.12
  * [Perl interpreter]: Probably already installed on your system
  * [OpenSSH]: If you want to transfer backups from/to remote locations
  * [mbuffer]: If you want rate limiting and progress bars

  [btrfs-progs]: https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/
  [Perl interpreter]: https://www.perl.org
  [OpenSSH]: https://www.openssh.org
  [mbuffer]: https://www.maier-komor.de/mbuffer.html


Synopsis
========

Please consult the [btrbk(1)] man-page provided with this package for
a full description of the command line options.

  [btrbk(1)]: https://digint.ch/btrbk/doc/btrbk.1.html


Configuration
=============

Before running `btrbk`, you will need to create a configuration
file. You might want to take a look at `btrbk.conf.example` provided
with this package. For a detailed description, please consult the
[btrbk.conf(5)] man-page.

After a configuration change, it is highly recommended to check it by
running btrbk with the `-n,--dryrun` option:

    btrbk -c /path/to/myconfig -v -n run

This will read all btrfs information on the source/target filesystems
and show what actions would be performed (without writing anything to
the disks).

The examples below assume that the btrfs subvolume containing `home`
and `rootfs` is mounted at `/mnt/btr_pool`. This is usually the btrfs
root subvolume, which always has `subvolid=5`.

Mounting `subvolid=5` is *recommended* (mandatory for btrbk < v0.32.0)
if you want to backup your root filesystem `/`.

/etc/fstab:

    /dev/sda1  /mnt/btr_pool  btrfs  subvolid=5,noatime  0 0

Note that some default btrfs installations (e.g. Ubuntu) use subvolume
names `@` for rootfs (mounted at `/`) and `@home` for `/home`, as a
naming convention. If this is the case on your file system, replace
the `subvolume` declarations in the examples accordingly.

  [btrbk.conf(5)]: https://digint.ch/btrbk/doc/btrbk.conf.5.html


Example: Local Regular Snapshots (time-machine)
-----------------------------------------------

The simpliest use case is to only create snapshots of your data. This
will obviously not protect it against hardware failure, but can be
useful for:

  * protection against inadvertent changes or deletions
  * keeping past states of copies from rsync or similar tools

Let's assume you need regular snapshots of your home directory, which
is located in the subvolume `home` of the volume `/mnt/btr_pool`. The
snapshots are to be stored in `btrbk_snapshots` (on the same volume).

/etc/btrbk/btrbk.conf:

    timestamp_format        long
    snapshot_preserve_min   18h
    snapshot_preserve       48h

    volume /mnt/btr_pool
      snapshot_dir btrbk_snapshots
      subvolume home

Notice that the `target` option is not provided, and btrbk will only
manage snapshots located on the same volume in `snapshot_dir`. Btrbk
does not create subdirs by default, the snapshot directory must first
be created manually:

    sudo mkdir /mnt/btr_pool/btrbk_snapshots

The "volume" section is merely used as a specifier for a base
directory, and can be skipped if you prefer to configure everything
using absolute paths. The above configuration can also be written as:

    snapshot_dir /mnt/btr_pool/btrbk_snapshots
    subvolume    /mnt/btr_pool/home

If you don't want to mount the btrfs root filesystem to
`/mnt/btr_pool`, you might as well configure it like this:

    snapshot_dir /btrbk_snapshots
    subvolume    /home

Start a dry run:

    sudo btrbk run -n

Create the first snapshot:

    sudo btrbk run

If it works as expected, configure a cron job to run btrbk hourly:

/etc/cron.hourly/btrbk:

    #!/bin/sh
    exec /usr/bin/btrbk -q run

Snapshots will now be created every hour, kept for 48h
(`snapshot_preserve`), then automatically removed.

With this setup, the snapshots will be kept at least for 18 hours
(`snapshot_preserve_min`). This can be useful to create manual
snapshots by calling `sudo btrbk run` on the command line and keep
them around for a while, in addition to the regular snapshots.


Example: Backups to USB Disk
----------------------------

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
    your cron job) run btrbk
  * keep daily snapshots for 14 days (very handy if you are on
    the road and the backup disk is not attached)
  * keep monthly backups forever
  * keep weekly backups for 10 weeks
  * keep daily backups for 20 days

/etc/btrbk/btrbk-mylaptop.conf:

    snapshot_preserve_min   2d
    snapshot_preserve      14d

    # Create snapshots only if the backup disk is attached
    #snapshot_create ondemand

    target_preserve_min    no
    target_preserve        20d 10w *m

    snapshot_dir           btrbk_snapshots

    volume /mnt/btr_pool
      target /mnt/btr_backup/mylaptop
      subvolume rootfs
      subvolume home
      [...]


/etc/cron.daily/btrbk:

    #!/bin/sh
    exec /usr/bin/btrbk -q -c /etc/btrbk/btrbk-mylaptop.conf run


  * This will create snapshots on a daily basis:
    * `/mnt/btr_pool/btrbk_snapshots/rootfs.YYYYMMDD`
    * `/mnt/btr_pool/btrbk_snapshots/home.YYYYMMDD`
  * And create incremental backups in:
    * `/mnt/btr_backup/mylaptop/rootfs.YYYYMMDD`
    * `/mnt/btr_backup/mylaptop/home.YYYYMMDD`

If you prefer triggering the backups manually, change the cron command
to run the `snapshot` action instead of `run`. Start the backups
manually by running:

    # btrbk resume

For a quick additional snapshot of your home, run:

    # btrbk snapshot home


Example: Host-initiated Backup on Fileserver
--------------------------------------------

Let's say you have a fileserver at "myserver.mydomain.com" where you
want to create backups of your laptop disk, the config would look like
this:

    ssh_identity /etc/btrbk/ssh/id_rsa

    volume /mnt/btr_pool
      subvolume rootfs
        target /mnt/btr_backup/mylaptop
        target ssh://myserver.mydomain.com/mnt/btr_backup/mylaptop

In addition to the backups on your local usb-disk mounted at
`/mnt/btr_backup/mylaptop`, incremental backups would also be pushed
to `myserver.mydomain.com`.


Example: Fileserver-initiated Backups from Several Hosts
--------------------------------------------------------

If you're a sysadmin and want to trigger backups directly from your
fileserver, the config would be something like:

    ssh_identity /etc/btrbk/ssh/id_rsa

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


Example: Multiple Btrbk Instances
---------------------------------

Let's say we have a host (at 192.168.0.42) running btrbk with the
setup of the time-machine example above, and we need a backup server
to only fetch the snapshots.

/etc/btrbk/btrbk.conf (on backup server):

    target_preserve_min        no
    target_preserve            0d 10w *m

    volume ssh://192.168.0.42/mnt/btr_pool
      target /mnt/btr_backup/my-laptop
      subvolume home
        snapshot_dir           btrbk_snapshots
        snapshot_preserve_min  all
        snapshot_create        no

If the server runs btrbk with this config, 10 weeklies and all
monthlies are received from 192.168.0.42. The source filesystem is
never altered because of `snapshot_preserve_min all`.


Example: Virtual Machine Setup
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


Example: Backup from non-btrfs Source
-------------------------------------

If you want to make backups from a filesystem other than btrfs
(e.g. ext4 or reiserfs), you need to create a *synchronization
subvolume* on the backup disk:

    # btrfs subvolume create /mnt/btr_backup/myhost_sync

Configure btrbk to use `myhost_sync` as source subvolume:

    volume /mnt/btr_backup
      subvolume myhost_sync
        snapshot_name           myhost

        snapshot_preserve_min   latest
        snapshot_preserve       14d 20w *m

The btrbk package provides the "btrbk-mail" script, which automates
the synchronization using rsync, and can be run as cron job or systemd
timer unit. For configuration details, see the config section in
"/contrib/cron/btrbk-mail".

Alternatively, you can run any synchronization software prior to
running btrbk. Something like:

    #!/bin/sh
    rsync -az --delete \
          --inplace --numeric-ids --acls --xattrs \
          -e 'ssh -i /etc/btrbk/ssh/id_rsa' \
          myhost.mydomain.com:/data/ \
          /mnt/btr_backup/myhost_sync/

    exec /usr/bin/btrbk -q run

This will produce snapshots `/mnt/btr_backup/myhost.20150101`, with
retention as defined with the snapshot_preserve option.


Example: Encrypted Backup to non-btrfs Target
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
that the btrbk package is not required on the remote side, but you
will need the `btrfs` executable from the [btrfs-progs] package.


### Create SSH Key Pair

On the client side, create a ssh key dedicated to btrbk, without
password protection:

    ssh-keygen -t rsa -b 4096 -f /etc/btrbk/ssh/id_rsa -C btrbk@mydomain.com -N ""

The content of the public key (/etc/btrbk/ssh/id_rsa.pub) is used for
authentication in "authorized_keys" on the server side (see [sshd(8)]
for details).


### Allow Root Login

The most straight forward setup is to allow root login on the remote
host. If this is not an option for you, refer to the more complex
"Dedicated Btrbk User Login" section below.

/etc/ssh/sshd_config:

    PermitRootLogin prohibit-password

Add your btrbk public key to "/root/.ssh/authorized_keys" on the
server, and you are good to go.


### Restrict Access

Restrict ssh access to a static IP address within your network. On the
remote host, either add a "Match" block in:

/etc/ssh/sshd_config:

    Match Address 192.168.0.42

Or restrict in authorized_keys:

    from="192.168.0.42" <pubkey>...

Consult the [sshd_config(5)] man-page for a detailed explanation and
more options.


Dedicated Btrbk User Login (optional)
-------------------------------------

If allowing root login is not an option for you, there are several
ways to restrict SSH access to a regular user.


### Option 1: Use sudo

On the client side, configure btrbk use the sudo backend. This changes
the ssh calls to btrfs commands to `sudo btrfs <subcommand>
<options>`.

/etc/btrbk/btrbk.conf:

    backend_remote btrfs-progs-sudo

On the remote host, grant root permissions for the "btrfs" command
groups (subcommands) in "/etc/sudoers". If you are using
[ssh_filter_btrbk(1)], also add the `ssh_filter_btrbk.sh --sudo`
option in "authorized_keys" (see below).


### Option 2: Use btrfs-progs-btrbk

Instead of using the all-inclusive `btrfs` command,
"btrfs-progs-btrbk" allows you to restrict privileges to its
subcommands using linux capabilities(7) or setuid.

Note that the "btrfs-progs-btrbk" package is not available on all
linux distributions, you might need to build and install it on your
own (refer to [btrfs-progs-btrbk] on GitHub for more details).

/etc/btrbk/btrbk.conf:

    backend_remote btrfs-progs-btrbk

Make sure that only the required binaries with elevated privileges can
be called by the btrbk user. For example, on a server acting as "btrbk
source", allow only the following binaries for the "btrbk" group:

    # getcap /usr/bin/btrfs-*
    /usr/bin/btrfs-send cap_dac_read_search,cap_fowner,cap_sys_admin=ep
    /usr/bin/btrfs-subvolume-delete cap_dac_override,cap_sys_admin=ep
    /usr/bin/btrfs-subvolume-list cap_dac_read_search,cap_fowner,cap_sys_admin=ep
    /usr/bin/btrfs-subvolume-show cap_dac_read_search,cap_fowner,cap_sys_admin=ep
    /usr/bin/btrfs-subvolume-snapshot cap_dac_override,cap_dac_read_search,cap_fowner,cap_sys_admin=ep
    
    # ls -l /usr/bin/btrfs-*
    -rwx--x--- 1 root btrbk  /usr/bin/btrfs-send
    -rwx--x--- 1 root btrbk  /usr/bin/btrfs-subvolume-delete
    -rwx--x--- 1 root btrbk  /usr/bin/btrfs-subvolume-list
    -rwx--x--- 1 root btrbk  /usr/bin/btrfs-subvolume-show
    -rwx--x--- 1 root btrbk  /usr/bin/btrfs-subvolume-snapshot


Restrict Commands with "ssh_filter_btrbk.sh" (optional)
-------------------------------------------------------

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


  [ssh_filter_btrbk(1)]: https://digint.ch/btrbk/doc/ssh_filter_btrbk.1.html
  [sshd(8)]: https://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man8/sshd.8
  [sshd_config(5)]: https://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man5/sshd_config
  [btrfs-progs-btrbk]: https://github.com/digint/btrfs-progs-btrbk


Restoring Backups
=================

Btrbk does not provide any mechanism to restore your backups, this has
to be done manually. In the instructions below, we assume that you
have a btrfs volume mounted at `/mnt/btr_pool`, and the subvolume you
want to restore is at `/mnt/btr_pool/data`.

**Important**: don't use `btrfs property set` to make a subvolume
read-write after restoring. This is a low-level command, and leaves
"Received UUID" in a false state which causes btrbk to fail on
subsequent incremental backups. Instead, use `btrfs subvolume
snapshot` (without `-r` flag) as described below.


### Step 0: Identify Subvolume

    # list snapshots managed by btrbk
    btrbk list snapshots

    # alternative: list all subvolumes
    btrbk ls /
    btrbk ls -L /

From the list, identify the snapshot you want to restore. Let's say it's
`/mnt/btr_pool/_btrbk_snap/data.20150101`.


### Step 1: Restore Backup
(skip this step if you restore from a snapshot)

    # locally mounted backup disk
    btrfs send /mnt/btr_backup/data.20150101 | btrfs receive /mnt/btr_pool/

    # from / to remote host
    ssh root@remote btrfs send /mnt/btr_backup/data.20150101 | btrfs receive /mnt/btr_pool/
    btrfs send /mnt/btr_backup/data.20150101 | ssh root@remote btrfs receive /mnt/btr_pool/

**Hint**: Try to send-receive backups incrementally if possible. In
case you still have common snapshot / backup pairs (i.e. both
"snapshot_subvol" and "target_subvol" are listed above), use `btrfs
send -p <parent>`.

From this point on, `data.20150101` on both disks can be used as
parents for subsequent send-receive operations, and a *received_uuid*
relationship is established (see below).


### Step 2: Create read-write Subvolume

    # if still present, move broken subvolume away
    mv /mnt/btr_pool/data /mnt/btr_pool/data.BROKEN

    # create read-write subvolume
    btrfs subvolume snapshot /mnt/btr_pool/data.20150101 /mnt/btr_pool/data

Your `data` subvolume is restored, you can carry on with incremental
backups to `/mnt/btr_backup`.


### Step 3: Cleanup

    # if everything went fine, delete the broken subvolume
    btrfs subvolume delete /mnt/btr_pool/data.BROKEN

Make sure to keep `data.20150101` subvolumes on both disks at least
until you created a new backup using btrbk, in order to keep the
incremental chain alive.


Btrfs Relationship (technical note)
-----------------------------------

    btrbk origin -t /mnt/btr_backup/data.20150101
    btrbk ls -L /mnt/btr_pool /mnt/btr_backup

  * **received_uuid** relationship: *correlated*, *identical*
    read-only subvolumes, cross-filesystem.

        a.received_uuid = b.received_uuid
        a.received_uuid = b.uuid

    * Required for subvolumes used as parent (or clone-src) of
      send-receive operations.
    * Present on subvolumes created by `btrfs send | btrfs receive`.
    * `/mnt/btr_pool/data.20150101 === /mnt/btr_backup/data.20150101`

  * **parent_uuid** relationship: "is-snapshot-of"

        a.parent_uuid = b.uuid

    * Present on subvolumes created by `btrfs subvolume snapshot` or
      `btrfs send -p | btrfs receive`.
    * Used by btrbk to determine best parent.
    * `/mnt/btr_pool/data.20150101 <-- /mnt/btr_pool/data`


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
  * Talk to us on [Libera.Chat] in `#btrbk`.
  * Contact the author via email (the email address can be found in
    the sources).

Any feedback is appreciated!

  [btrbk project page on GitHub]: https://github.com/digint/btrbk
  [issues tracker]: https://github.com/digint/btrbk/issues
  [Libera.Chat]: https://libera.chat


License
=======

btrbk is free software, available under the [GNU General Public
License, Version 3 or later][GPL-3.0-or-later].

  [GPL-3.0-or-later]: https://www.gnu.org/licenses/gpl.html
