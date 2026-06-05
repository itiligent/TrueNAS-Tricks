## Re-Enable & Adjust the Encrypted Dataset Key Sync Interval

If your TrueNAS system uses ZFS dataset encryption, TrueNAS periodically runs an encrypted dataset key database sync task from:

```text
/usr/lib/python3/dist-packages/middlewared/plugins/pool_/dataset_encryption_info.py
```

However, the included patch files presume zfs encryption is not in use for home NAS systems, and disables this task to prevent uneeded daily disk wakes. Te re-eable the sync task you must uncomment this line in the patch file as follows:

```python
@periodic(86400)
```

The TrueNAS default value is `86400` seconds, which performs the sync every 24 hours.

For systems where disk spindown is important, this interval can be increased to reduce unnecessary encrypted dataset/key checks.

For most home NAS systems with stable encrypted dataset configuration, a weekly interval is a reasonable balance:

```python
@periodic(604800)
```

### Caution
If you are using zfs encryption do not fully disable this function unless you understand the impact. This task helps TrueNAS keep its encrypted dataset key database in sync. Increasing the interval is safer than commenting it out completely.

If you regularly create, delete, re-key, export, or replicate encrypted datasets, keep the TrueNAS default.
