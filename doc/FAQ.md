btrbk FAQ
=========

How can I auto-mount btrfs filesystems used by btrbk?
-----------------------------------------------------

Given that the "volume" lines in the btrbk configuration file are
valid mount-points, you can loop through the configuration and mount
the volumes like this:

    #!/bin/sh
    btrbk list volume --format=raw | while read line; do
        eval $line
        $volume_rsh mount $volume_path
    done

Note that the `btrbk list` command accepts filters (see [btrbk(1)],
FILTER STATEMENTS), which means you can e.g. add "group automount"
tags in your configuration and dump only the volumes of this group:
`btrbk list volume automount`.

  [btrbk(1)]: http://www.digint.ch/btrbk/doc/btrbk.html


Why is it not possible to backup '/' (btrfs root) ?
---------------------------------------------------

or in other words: why does this config not work:

/etc/btrbk/btrbk.conf:

    volume /
      subvolume /
        snapshot_name rootfs

*ERROR: Only relative files allowed for option "subvolume"*.


### Answer

btrbk is designed to never alter your source subvolume. In the config
above, the btrbk snapshots would be created *inside* the source
subvolume, altering it.

The same applies to **any "btrfs root" mount point** (subvolid=0). In
the example below, you will **not be able to backup** `/mnt/data`
using btrbk:

/etc/fstab:

    /dev/sda1  /mnt/data  btrfs  subvolid=0 [...]

btrbk is designed to operate on the subvolumes *within* `/mnt/data`.
The recommended way is to split your data into subvolumes, e.g.:

     # btrfs subvolume create /mnt/data/www
     # btrfs subvolume create /mnt/data/mysql
     # btrfs subvolume create /mnt/data/projectx

This way you make full advantage of the btrfs filesystem, as all your
data now has a name, which helps organizing things a lot. This gets
even more important as soon as you start snapshotting and
send/receiving.

The btrbk configuration for this would be:

    volume /mnt/data
      subvolume www
        [...]
      subvolume mysql
        [...]
      subvolume projectx
        [...]


### Tech Answer

While *btrfs root* (subvolid=0) is a regular subvolume, it is still
special: being the root node, it does not have a "name" inside the
subvolume tree.

Here, `/mnt/btr_pool` is mounted with `subvolid=0`:

    # btrfs sub show /mnt/btr_pool/
    /mnt/btr_pool is btrfs root

    # btrfs sub show /mnt/btr_pool/rootfs
    /mnt/btr_pool/rootfs
            Name:    rootfs
            uuid:    [...]


How should I organize my btrfs filesystem?
------------------------------------------

There's lots of ways to do this, and each one of them has its reason
to exist. Make sure to read the [btrfs SysadminGuide on
kernel.org](https://btrfs.wiki.kernel.org/index.php/SysadminGuide) as
a good entry point.

<!-- TODO: add links to recommendations for ubuntu and other distros -->


### btrfs root

If your linux root filesystem is btrfs, I recommend booting linux from
a btrfs subvolume, and use the btrfs root only as a container for
subvolumes (i.e. NOT booting from "subvolid=0"). This has the big
advantage that you can choose the subvolume in which to boot by simply
switching the `rootflags=subvol=<subvolume>` kernel boot option.

Example (/boot/grub/grub.cfg):

    menuentry 'Linux' {
      linux /boot/vmlinuz root=/dev/sdb3 ro rootflags=subvol=rootfs quiet
    }
    menuentry 'Linux (testing)' {
      linux /boot/vmlinuz root=/dev/sdb3 ro rootflags=subvol=rootfs_testing
    }

Note that btrbk snapshots and backups are read-only, this means you
have to create a run-time (rw) snapshot before booting into it:

    # btrfs subvolume snapshot /mnt/btr_pool/backup/btrbk/rootfs-20150101 /mnt/btr_pool/rootfs_testing


How do I convert '/' (subvolid=0) into a subvolume?
---------------------------------------------------

There's several ways to achieve this, the solution described below is
that it guarantees not to create new files (extents) on disk.

### Step 1: make a snapshot of your root filesystem

Assuming that '/' is mounted with `subvolid=0`:

    # btrfs subvolume snapshot / /rootfs

Note that this command does NOT make any physical copy of the files of
your subvolumes within "/", it will only add some metadata.


### Step 2: make sure that "/rootfs/etc/fstab" is ok.

Add mount point for subvolid=0 to fstab, something like this:

/rootfs/etc/fstab:

    /dev/sda1  /mnt/btr_pool  btrfs  subvolid=0,noatime  0 0


### Step 3: boot from the new subvolume "rootfs".

Either add `rootflags=subvol=rootfs` to grub.cfg, or set subvolume
"rootfs" as default:

    # btrfs subvolume set-default <subvolid> /


### Step 4: after reboot, check if everything went fine:

First check your **system log** for btrfs errors, then:

    # btrfs subvolume show /
            Name:                   rootfs
            ...

Great, this tells us that we just booted into our new snapshot!

    # mount /mnt/btr_pool
    # btrfs subvolume show /mnt/btr_pool
    /mnt/btr_pool is btrfs root

This means that the root volume (subvolid=0) is correctly mounted.


### Step 5: delete old (duplicate) files

Carefully delete all old files from `/mnt/btr_pool`, except "rootfs"
and all other subvolumes within "/". You can list all these by typing:

    # btrfs subvolume list -a /mnt/btr_pool

Make sure you do NOT delete anything within the directories listed
here!

something like:

    # cd /mnt/btr_pool
    # rm -rf bin sbin usr lib var ...


What is the most efficient way to clone btrfs storage?
------------------------------------------------------

It is very common (and avisable!) to keep backups on a separate
location. In some situations, is is also required to transport the
data physically, either to the datacenter or to your safe in the
basement.


### Answer 1: Use external storage as "stream-fifo"

This example uses a USB disk as "stream-fifo" for transferring
(cloning) of btrfs subvolumes:

1. For all source subvolumes (in order of generation):

    `btrfs send /source/subvolX -p PARENT > /usbdisk/streamN`

2. At the target location, restore the streams (in order of
   generation):

    `cat /usbdisk/streamN | btrfs receive /target`

This approach has the advantage that you don't need to reformat your
USB disk. This works fine, but be aware that you may run into trouble
if a single stream gets corrupted, making all subsequent streams
unusable.


### Answer 2: Clone btrfs subvolumes

A more robust approach is to use the USB disk as secondary backup.
This has the advantage that possible errors can already be detected by
btrfs on the source side:

1. Initialize USB disk:

    `mkfs.btrfs /dev/usbX`

2. For all source subvolumes (in order of generation):

    `btrfs send /source/subvolX -p PARENT | btrfs receive /usbdisk/`

3. At the target location (in order of generation):

    `btrfs send /usbdisk/subvolX -p PARENT | btrfs receive /target`

If you simply want to have a clone of the source disk, skip step 3 and
store your USB disk in a safe. You will be able to use it for
restoring backups later, or *as a replacement for your backup disks*.

**Note that kernels >=4.1 and <4.4 have a bug when re-sending
subvolumes**, make sure you run a recent/patched kernel or step 3 will
fail. Read
[this thread on gmane](http://thread.gmane.org/gmane.comp.file-systems.btrfs/48798)
(the patch provided is confirmed working on kernels 4.2.x and 4.3.x).
