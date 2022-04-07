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

  [btrbk(1)]: https://digint.ch/btrbk/doc/btrbk.1.html


How can I setup a debian pre-install hook?
------------------------------------------

Create a file `/etc/apt/apt.conf.d/70btrbk`, e.g.:

    // create a btrfs snapshot before (un)installing packages
    Dpkg::Pre-Invoke {"/usr/bin/btrbk run /mnt/btr_pool/rootfs";};

In order to make sure that the snapshots are always generated and
nothing is deleted, add the btrbk command line options `--preserve
--override=snapshot_create=always`.


Why is "subvolume ." configuration not recommended?
---------------------------------------------------

Referring to a btrbk configuration like this:

    volume /
      subvolume .
        snapshot_name rootfs

Btrbk is designed to operate on the subvolumes *within* a root
subvolume. In the config above, the btrbk snapshots would be created
*inside* the source subvolume, altering it (from user perspective).
From btrfs perspective this is not a problem, as the snapshots are
separate subvolumes referring to the source subvolume and mapped into
the file system tree below the source subvolume.

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
subvolumes (i.e. NOT booting from "subvolid=5"). This has the big
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


How do I convert '/' (subvolid=5) into a subvolume?
---------------------------------------------------

There's several ways to achieve this, the solution described below
guarantees not to create new files (extents) on disk.

### Step 1: make a snapshot of your root filesystem

Assuming that '/' is mounted with `subvolid=5`:

    # btrfs subvolume snapshot / /rootfs

Note that this command does NOT make any physical copy of the files of
your subvolumes within "/", it will only add some metadata.


### Step 2: (optional) add the toplevel subvolume to fstab

Add mount point for subvolid=5 to fstab, something like this:

/rootfs/etc/fstab:

    /dev/sda1  /mnt/btr_pool  btrfs  subvolid=5,noatime  0 0

> This step is not critical for a proper root change, but will save
> your time by preventing further configurations/reboots and manually
> mounting the toplevel subvolume.


### Step 3: boot from the new subvolume "rootfs".

Either add `rootflags=subvol=rootfs` to grub.cfg, or set subvolume
"rootfs" as default:

    # btrfs subvolume set-default <subvolid> /

You can obtain `<subvolid>` via
`btrfs subvolume show /rootfs | grep "Subvolume ID"`

> Editing grub.cfg manually may lead you some troubles if you perform
> some actions that will fire `grub-mkconfig`.


### Step 4: after reboot, check if everything went fine:

First check your **system log** for btrfs errors:

    cat /var/log/messages | grep -i btrfs | grep -i error

then check if current `/` is our new subvolume:

    # btrfs subvolume show /
            Name:                   rootfs
            ...

Great, this tells us that we just booted into our new snapshot!

    # btrfs subvolume show /mnt/btr_pool
    /mnt/btr_pool is toplevel subvolume

This means that the root volume (subvolid=5) is correctly mounted.


### Step 5: delete old (duplicate) files

Carefully delete all old files from `/mnt/btr_pool`, except "rootfs"
and any other subvolumes within "/mnt/btr_pool". In other words,
delete any folders that are NOT LISTED by `btrfs subvolume list -a
/mnt/btr_pool`:

    # cd /mnt/btr_pool
    # mkdir TO_BE_REMOVED
    # mv bin sbin usr lib var ... TO_BE_REMOVED

Then reboot. If everything went fine, remove the directory:

    # cd /mnt/btr_pool
    # rm -rf TO_BE_REMOVED


What is the most efficient way to clone btrfs storage?
------------------------------------------------------

It is very common (and avisable!) to keep backups on a separate
location. In some situations, it is also required to transport the
data physically, either to the datacenter or to your safe in the
basement.


### Answer 1: Use "btrbk archive"

A robust approach is to use external disks as archives (secondary
backups), and regularly run "btrbk archive" on them. As a nice side
effect, this also detects possible read-errors on your backup targets
(Note that a "btrfs scrub" is still more effective for that purpose).

See **btrbk archive** command in [btrbk(1)] for more details.


### Answer 2: Use external storage as "stream-fifo"

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


### Warning: Avoid using "dd" on btrfs filesystems!

If you use `dd` (e.g. in order to clone a partition), make sure you
don't mount the cloned filesystem at the same time as the original
one. You will end up having multiple filesystems **sharing identical
UUID**, which will break things. If you _really_ want to do this, make
sure to run:

    btrfstune -u /dev/sdaX

which changes the UUID of the given device. Note that the btrfs
subvolumes still share identical UUID's, but at least the kernel can
cope with it (see
[this post on stackexchange](https://unix.stackexchange.com/questions/246976/btrfs-subvolume-uuid-clash)
).

Btrbk on the other hand relies on subvolume UUID's being *universally
unique*, and uses them as hash keys for identifying and caching
filesystem and subvolume trees, which leads to undefined behavior if
multiple identical UUID's are processed.


I'm getting an error: Aborted: "Received UUID" is set
-----------------------------------------------------

You probably restored a backup with send-receive, and made it
read/write using `btrfs property set`. This is bad, as all snapshots
and backups will inherit this identical "Received UUID", which results
in all these subvolumes will be treated as "containing same data".

To fix this, create a "proper" snapshot:

    # cd /mnt/btr_pool
    # mv mysubvolume mysubvolume.broken
    # btrfs subvolume snapshot mysubvolume.broken mysubvolume

Now, `mysubvolume` should have an empty "Received UUID". Note that in
order to have a clean environment, you also need to fix all subvolumes
(snapshots as well as backups) that you created with the broken
subvolume.

Check if there are more broken subvolumes:

    # btrfs subvolume show mysubvolume.broken
    # btrfs subvolume list -a -R /mnt/btr_pool | grep <"Received UUID" from above>
    # btrfs subvolume list -a -R /mnt/btr_backup | grep <"Received UUID" from above>

Either delete them (they won't be used for incremental send-receive
anyways), or clean them as follows:

    # btrfs subvolume snapshot listed_ro_subvol listed_ro_subvol.rw
    # btrfs subvolume delete listed_ro_subvol
    # btrfs subvolume snapshot -r listed_ro_subvol.rw listed_ro_subvol
    # btrfs subvolume delete listed_ro_subvol.rw

Finally, don't forget to delete the broken source subvolume:

    # btrfs subvolume delete mysubvolume.broken

You should now have a clean environment, and btrbk will not complain
any more.


I'm getting an error: Aborted: subvolume has no UUID
----------------------------------------------------

If your file system was created with btrfs-progs < 4.16, the btrfs
root subvolume (id=5) has no UUID. You can check this by calling:

    # btrfs subvolume show /mnt/btr_pool
    /
        Name:    <FS_TREE>
        UUID:    -
        [...]

Without a UUID, the snapshots would get no parent_uuid, leaving btrbk
unable to track parent/child relationships. In this case, btrbk
refuses to create snapshots and backups.
