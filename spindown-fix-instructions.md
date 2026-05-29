# TrueNAS Spindown Fix Script Instructions

## Preparing the script:

**1. Place these files in the same TrueNAS directory eg. `/home/trunas_admin`:**
```bash
spindown-overlay.sh
spindown.patch.fixed
```

**2. Edit the script `OVERLAY` setting to your preferred TrueNAS path for the overlay: `nano spindown-overlay.sh`**
```bash
OVERLAY="/mnt/your_preferred_ssd_tank/overlay"
```
Choose a location that is available at boot. This path must also be on a mounted SSD pool.

**3. Make the script executable**
```bash
chmod +x spindown-overlay.sh
```

## Running the script:
The script needs to be run several times with different arguments to complete all the configuration stages in sequence:

### **1st Run Argument:**
```bash
sudo bash ./spindown-overlay.sh copy
```

This command:
- Removes any existing bind mounts first.
- Copies a selection of original TrueNAS middleware files into the configured overlay directory.

### **2nd Run Argument:**
```bash
sudo bash ./spindown-overlay.sh dry-run
```

This command:
- This checks whether `spindown.patch.fixed` can be applied cleanly to the copied overlay files.
- **Do not continue if for some reason the dry run fails.**

### **3rd Run Argument:**
```bash
sudo bash ./spindown-overlay.sh apply
```

This command:
- Applies the patch to the copied overlay files.
- Bind-mounts the patched files as overlay files over the native TrueNAS system files.
- Restarts `middlewared`.
- Generates a boot helper script that (to be be manually configured as a POST INIT task in a following step)

After this step, TrueNAS should now be using the patched middleware files. (These settings will not yet remain after a reboot.)

### **4th Run Argument:**
```bash
sudo bash ./spindown-overlay.sh status
```
This command:
- Helps to confirm that each overlay file exists and that each target file is currently bind-mounted.

### **5th Run Argument:**
```bash
sudo bash ./spindown-overlay.sh init-command
```
This command:
- Prints on screen the exact TrueNAS POST INIT command you will need to add to TrueNAS startup.

Then, in the TrueNAS GUI under System | Advanced Setting | Init/Shutdown scripts add the supplied boot command with these additional settings:

```text
Type: Command
When: POST INIT
Enabled: Yes
Timeout: 60 seconds or higher
```

### To temporarily Revert to original TrueNAS system files:
```bash
sudo bash ./spindown-overlay.sh unmount
```

### Recommended Workflow for Updating TrueNAS:

1. Revert the system back to its original state by disabling the POST INIT boot command
2. Reboot
3. Check to make sure no overlays are present: `sudo bash ./spindown-overlay.sh status`
4. Update TrueNAS
5. Repeat the patching process to the updated TrueNAS system
```bash
sudo bash ./spindown-overlay.sh copy
sudo bash ./spindown-overlay.sh dry-run
sudo bash ./spindown-overlay.sh apply
```
6. Re-enable the POST INIT boot command
7. Reboot
8. Check to make sure the overlays are present `bash ./spindown-overlay.sh status`
