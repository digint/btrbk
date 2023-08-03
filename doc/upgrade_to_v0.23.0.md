Upgrading to btrbk-v0.23.0
==========================

In order to keep btrbk simple and intuitive while adding new features,
it became inevitable to change the semantics of the "retention policy"
related configuration options.


What has changed?
-----------------

### Preserve *first* instead of *last* snapshot/backup

btrbk used to *always* transfer the latest snapshot to the target
location, while considering the *last* snapshot/backup of a day as a
daily backup (and also the last weekly as a monthly). This made it
very cumbersome when running btrbk in a cron job as well as manually,
because the last manually created snapshot was immediately transferred
on every run, and used as the daily backup (instead of the one created
periodically by the cron job).

The new semantics are to consider the *first* (instead of *last*)
snapshot of a hour/day/week/month as the one to be preserved, while
only transferring the snapshots needed to satisfy the target retention
policy.


### Preserve snapshots for a minimum amount of time

In order to specify a minimum amount of time in which *all* snapshots
should be preserved, the new "snapshot_preserve_min" and
"target_preserve_min" configuration options were introduced. This was
previously covered by "snapshot_preserve_daily", which caused a lot of
confusion among users.


Upgrading the configuration file: /etc/btrbk/btrbk.conf
-------------------------------------------------------

Please read the description of the "run" command in [btrbk(1)], as
well as the "RETENTION POLICY" section in [btrbk.conf(5)] for a
detailed description. Make sure to understand the new concept, and run
`btrbk --print-schedule dryrun` after updating the configuration.


### Upgrade retention policy

If you want the same behaviour as before:

    # replace this:
    snapshot_preserve_daily   <daily>
    snapshot_preserve_weekly  <weekly>
    snapshot_preserve_monthly <monthly>

    # with:
    snapshot_preserve_min  <daily>d
    snapshot_preserve      <weekly>w <monthly>m

    # ... do the same with "target_preserve_*" options


But what you probably want is something like:

    snapshot_preserve_min  5d
    snapshot_preserve      <daily>d <weekly>w <monthly>m

    target_preserve_min    no
    target_preserve        <daily>d <weekly>w <monthly>m *y

This states:

  * Keep all snapshots for five days (no matter how many there are)
  * Transfer only the first snapshot of a day to the target
  * Keep all "first snapshots of a day" for `<daily>` days, etc.


### Upgrade "resume_missing"

If you have a line: "resume_missing yes" somewhere in your config,
simply remove it. btrbk always resumes missing backups.

If you have "resume_missing no", you can imitate this behaviour by
setting:

    target_preserve_min  latest
    target_preserve      no

This states: "always transfer the latest snapshot to the target".


  [btrbk(1)]: https://digint.ch/btrbk/doc/btrbk.1.html
  [btrbk.conf(5)]: https://digint.ch/btrbk/doc/btrbk.conf.5.html
