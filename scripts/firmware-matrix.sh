#!/usr/bin/env bash
# Boots an MpireOS ISO the ways real machines and hypervisors do, and checks
# that each one gets as far as starting the Linux kernel.
#
# Usage: scripts/firmware-matrix.sh path/to.iso [only-this-case]
#
# Cases cover Proxmox's choices: SeaBIOS (legacy BIOS) or OVMF (UEFI), the
# i440fx or q35 machine, and the ISO on an IDE, SATA or VirtIO SCSI CD drive,
# plus the ISO written to a USB stick / disk. The CPU model is Proxmox's default.
# A case passes when the kernel prints to the serial console (the boot menus
# add console=ttyS0). Failing cases get a screenshot in the log.
set -uo pipefail
iso="$(realpath "$1")"
only="${2:-}"
work="$(mktemp -d)"
timeout="${CASE_TIMEOUT:-240}"
source "$(dirname "$0")/qemu-screenshot.sh"

accel=(-accel tcg -cpu qemu64)
[[ -w /dev/kvm ]] && accel=(-enable-kvm -cpu x86-64-v2-AES)

ovmf_code="" ovmf_vars=""
for f in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do [[ -f $f ]] && { ovmf_code=$f; break; }; done
for f in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do [[ -f $f ]] && { ovmf_vars=$f; break; }; done

cd_args() {  # bus
    case "$1" in
        ide)  echo "-drive file=$iso,media=cdrom,if=ide,index=2,readonly=on" ;;
        sata) echo "-drive file=$iso,media=cdrom,if=none,id=cd0,readonly=on -device ide-cd,drive=cd0,bus=ide.2,bootindex=0" ;;
        scsi) echo "-device virtio-scsi-pci,id=scsi0 -drive file=$iso,media=cdrom,if=none,id=cd0,readonly=on -device scsi-cd,drive=cd0,bus=scsi0.0,bootindex=0" ;;
        usb)  echo "-device qemu-xhci -drive file=$iso,format=raw,if=none,id=stick,readonly=on -device usb-storage,drive=stick,bootindex=0" ;;
    esac
}

run_case() {  # name firmware machine bus
    local name=$1 fw=$2 machine=$3 bus=$4
    local log="$work/$name.log" monitor="$work/$name.sock"
    local -a firmware=()
    if [[ $fw == uefi ]]; then
        [[ -n $ovmf_code ]] || { echo "SKIP $name (no OVMF)"; return 0; }
        cp "$ovmf_vars" "$work/$name-vars.fd"
        firmware=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=$ovmf_code"
                  -drive "if=pflash,format=raw,unit=1,file=$work/$name-vars.fd")
    fi
    : > "$log"
    # shellcheck disable=SC2046
    qemu-system-x86_64 "${accel[@]}" -machine "$machine" -m 2048 -smp 2 "${firmware[@]}" \
        $(cd_args "$bus") -boot menu=off \
        -vga std -display none -serial "file:$log" -monitor "unix:$monitor,server,nowait" \
        -nic none &
    local qemu=$! t
    for ((t = 0; t < timeout; t += 2)); do
        if grep -qa -e 'Linux version' -e 'Run /init' -e 'Welcome to' "$log"; then
            echo "PASS $name (kernel started after ~${t}s)"
            kill $qemu 2>/dev/null; wait $qemu 2>/dev/null
            return 0
        fi
        kill -0 $qemu 2>/dev/null || break
        sleep 2
    done
    echo "FAIL $name (no kernel output after ${timeout}s)"
    qemu_screenshot "$monitor" "$work/$name.ppm"
    tail -n 20 "$log"
    kill $qemu 2>/dev/null; wait $qemu 2>/dev/null
    return 1
}

cases=(
    "bios-i440fx-ide   bios pc  ide"
    "bios-q35-sata     bios q35 sata"
    "bios-i440fx-scsi  bios pc  scsi"
    "bios-q35-scsi     bios q35 scsi"
    "bios-q35-usb      bios q35 usb"
    "uefi-i440fx-ide   uefi pc  ide"
    "uefi-q35-sata     uefi q35 sata"
    "uefi-q35-scsi     uefi q35 scsi"
    "uefi-q35-usb      uefi q35 usb"
)
failed=0
for c in "${cases[@]}"; do
    read -r name fw machine bus <<< "$c"
    [[ -n $only && $only != "$name" ]] && continue
    run_case "$name" "$fw" "$machine" "$bus" || failed=$((failed + 1))
done
if (( failed )); then
    echo "firmware-matrix: $failed case(s) failed"
    exit 1
fi
echo "firmware-matrix: all cases boot"
