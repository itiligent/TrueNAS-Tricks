# TrueNAS Spindown-Fix Script Instructions

### 1. Preparing the script

Place these files in the same TrueNAS directory, eg. `/home/trunas_admin`

```bash
spindown-fix.sh
spindown-v25.patch or spindown-v26.patch
```
---

#### 1.1. Optional: Tune the SMART polling interval

The patch ensures that SMART will only ever poll awake disks.

> [!NOTE]
> If your HDD standby timeout is **6 hours or longer**, you must increase the  SMART polling `IntervalSchedule` of  `360` minutes set by the patch.
> 
> (If SMART polling hits an awake disk before it can reach standby, it resets the standby timer prevents the disk from ever sleeping).
> 
> Increasing this interval increases SMART telemetry latency. Health, temperature, and alert updates may take up to the maximum interval to appear.
>
> This interval can also be reduced for shorter HDD standby timeouts. The simple rule is that **this interval must always be longer than the disk standby timeout.**  The TrueNAS default is **90 minutes**, a main cause of disks regularly being awoken/kept awake by background tasks.

```bash
nano spindown-[version].patch
```

Look for this line and edit:
```bash
schedule = IntervalSchedule(timedelta(minutes=numeric_value_in_minutes))
```


#### 1.2. Only If Using ZFS Encryption 
> [!Warning]
> Certain ZFS encryption tasks periodically wake disks, but the patch disables these. You **must** follow [this extra step](https://github.com/itiligent/TrueNAS-Tricks/blob/main/spindown-fix-with-zfs-encryption.md) before proceeding further.

---


### 2. Edit the script's `OVERLAY=` & `PATCH=` values to your required settings:

```bash
nano spindown-fix.sh
```

Choose an overaly location that is available at boot. This path must be on an SSD pool.
```bash
OVERLAY="/mnt/your_preferred_ssd_tank/overlay"
```

Configure the script to use the correct patch version: 
```bash
PATCH="$SCRIPT_DIR/spindown-[version].patch"
```
---

### 3. Make the script executable
```bash
chmod +x spindown-fix.sh
```
---

## Running the Script

The script needs to be run several times with different arguments to complete all the configuration stages in sequence.

---

### 1st Run Argument

```bash
sudo bash ./spindown-fix.sh copy
```

This command:

* Removes any existing bind mounts first.
* Copies a selection of original TrueNAS middleware files into the new overlay directory.

---

### 2nd Run Argument

```bash
sudo bash ./spindown-fix.sh dry-run
```

This command:

* This tests whether `spindown-[version].patch` can be applied cleanly to the copied overlay files.
* **Do not continue if for some reason dry-run fails.**

---

### 3rd Run Argument

```bash
sudo bash ./spindown-fix.sh apply
```

This command:

* Applies the patch to the copied overlay files.
* Bind-mounts the patched overlay files over the native TrueNAS system files.
* Restarts `middlewared`

After this step, TrueNAS should now be using the patched middleware files. 

> [!NOTE]
> These settings will not yet remain after a reboot, boot persitence
> is configured in a following step.

---

### 4th Run Argument

```bash
sudo bash ./spindown-fix.sh status
```

This command:

* Helps to confirm that each overlay file exists and that each target file is currently bind-mounted.

---

### 5th Run Argument

```bash
sudo bash ./spindown-fix.sh boot-script
```

This command:

* Creates a custom script in the current directory to mount the new overalys at boot.
* Prints on screen the exact TrueNAS command you will need to call the newly created Init script.

Next, add the provided Init command under **System | Advanced Settings | Init/Shutdown scripts** with these additional settings:

```text
Type: Command
When: Pre Init
Enabled: Yes
Timeout: 60 seconds or higher
```

> [!NOTE]
> Note: On some systems, the overlays may not mount quickly enough during boot requiring a middleware restart, but this can clobber app services if done during startup.
>
> If after boot `sudo bash spindown-fix.sh status` shows the overlays is did not mount, or if the apps service is not running after boot, run the Pre Init boot script with a delayed middleware restart:
>
> ```bash
> ENABLE_DELAYED_RESTART=yes DELAY_SECONDS=300 bash /path/to/spindown-overlay-mount.sh
> ```

---

## Temporarily Revert to Original TrueNAS System Files

```bash
sudo bash ./spindown-fix.sh unmount
```

---

## Recommended Workflow for Updating TrueNAS

1. Revert the system back to its original state by disabling the Pre Init boot command.

2. Reboot.

3. Check to make sure no overlays are present:

   ```bash
   sudo bash ./spindown-fix.sh status
   ```

4. Update TrueNAS.

5. Repeat the patching process for the updated TrueNAS system
> [!NOTE]
> If you have performed a major TrueNAS version upgrade, you must 
> download the new version patch and then modify the `PATCH=` setting in `spindown-fix.sh`
 
 ```bash
PATCH="$SCRIPT_DIR/spindown-[verion].patch"
```

   ```bash
   sudo bash ./spindown-fix.sh copy
   sudo bash ./spindown-fix.sh dry-run
   sudo bash ./spindown-fix.sh apply
   ```

8. Re-enable the Pre Init boot command.

9. Reboot

10. Check to make sure the overlays are present:

   ```bash
   bash ./spindown-fix.sh status
   ```
