#!/usr/bin/env bash
# TrueNAS SCALE disk standby checker
# Default: HDDs only
# Use --all to include SSD/NVMe disks as well
#
# Shows:
# - current standby/active state for HDDs
# - TrueNAS disk metadata from midclt
# - WWN persistent disk ID where available

clear

MODE="hdd"

case "$1" in
  --all|-a)
    MODE="all"
    ;;
  --hdd|-h|"")
    MODE="hdd"
    ;;
  --help)
    echo "Usage:"
    echo "  sudo bash ~/diskstatus.sh        # HDDs only default"
    echo "  sudo bash ~/diskstatus.sh --hdd  # HDDs only"
    echo "  sudo bash ~/diskstatus.sh --all  # All disks"
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help"
    exit 1
    ;;
esac

if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

DISK_JSON="$($SUDO midclt call disk.query 2>/dev/null)"

get_tn_value() {
  local devname="$1"
  local field="$2"

  echo "$DISK_JSON" | jq -r --arg n "$devname" --arg f "$field" '
    .[]
    | select(.name == $n or .devname == $n)
    | .[$f] // empty
  ' 2>/dev/null | head -n1
}

get_wwn_id() {
  local dev="$1"
  local path=""

  for path in /dev/disk/by-id/wwn-*; do
    [[ -L "$path" ]] || continue
    [[ "$path" == *-part* ]] && continue

    if [[ "$(readlink -f "$path" 2>/dev/null)" == "$dev" ]]; then
      echo "$path"
      return 0
    fi
  done

  return 1
}

printf "%-12s %-22s %-12s %-10s %-28s %-22s %-24s %-s\n" \
  "DEVICE" "STATE" "TYPE" "SIZE" "MODEL" "SERIAL" "TRUENAS_DESC" "WWN_ID"

printf "%-12s %-22s %-12s %-10s %-28s %-22s %-24s %-s\n" \
  "------" "-----" "----" "----" "-----" "------" "------------" "------"

for d in /sys/block/sd* /sys/block/nvme*n1; do
  [[ -e "$d" ]] || continue

  dev="/dev/$(basename "$d")"
  devname="$(basename "$dev")"

  rota="$(cat "$d/queue/rotational" 2>/dev/null)"

  # Default mode: only show HDDs
  if [[ "$MODE" = "hdd" && "$rota" != "1" ]]; then
    continue
  fi

  size="$(lsblk -ndo SIZE "$dev" 2>/dev/null | sed 's/ //g')"
  tran="$(lsblk -ndo TRAN "$dev" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  tn_desc="$(get_tn_value "$devname" "description")"
  tn_model="$(get_tn_value "$devname" "model")"
  tn_serial="$(get_tn_value "$devname" "serial")"
  tn_type="$(get_tn_value "$devname" "type")"
  tn_bus="$(get_tn_value "$devname" "bus")"

  model="${tn_model:-unknown}"
  serial="${tn_serial:-unknown}"
  disk_type="${tn_type:-unknown}"
  bus="${tn_bus:-$tran}"

  [[ -z "$bus" ]] && bus="unknown"
  [[ -z "$size" ]] && size="unknown"
  [[ -z "$tn_desc" ]] && tn_desc="-"

  wwn_id="$(get_wwn_id "$dev")"
  [[ -z "$wwn_id" ]] && wwn_id="-"

  if [[ "$rota" = "1" ]]; then
    out="$($SUDO smartctl -n standby -i "$dev" 2>&1)"

    if echo "$out" | grep -qi "STANDBY"; then
      state="STANDBY/spun down"
    else
      state="active or idle"
    fi
  else
    state="SSD/NVMe - skipped"
  fi

  printf "%-12s %-22s %-12s %-10s %-28s %-22s %-24s %-s\n" \
    "$dev" "$state" "$disk_type/$bus" "$size" "$model" "$serial" "$tn_desc" "$wwn_id"
done
