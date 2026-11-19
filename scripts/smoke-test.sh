#!/usr/bin/env bash
# Boots an MpireOS ISO in QEMU and waits for the live desktop to start.
# Usage: scripts/smoke-test.sh path/to.iso [timeout-seconds]
# Passes when the image prints MPIREOS_DESKTOP_OK (Mpire Desktop's shell is up)
# and MPIREOS_SETUP_OK (the installer opened by itself) on its serial console.
set -euo pipefail
iso="$1"
timeout="${2:-1200}"
log="${SERIAL_LOG:-serial.log}"
shot="$(realpath -m "${SCREENSHOT:-live-desktop.ppm}")"
monitor="$(mktemp -u /tmp/qemu-monitor.XXXXXX)"
qmp="$(mktemp -u /tmp/qemu-qmp.XXXXXX)"
: > "$log"

accel=(-accel tcg)
if [[ -w /dev/kvm ]]; then accel=(-enable-kvm -cpu host); fi

# A stand-in AI model server on the host. The VM reaches it at 10.0.2.2,
# where mpire-ai's network search finds it (see mpire-boot-check, ci_ai).
python3 "$(dirname "$0")/../ai/tests/mock_server.py" 11434 127.0.0.1 0.08 &
mock_ai=$!

qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 \
    -cdrom "$iso" -boot d \
    -vga std -display none \
    -serial "file:$log" \
    -monitor "unix:$monitor,server,nowait" \
    -qmp "unix:$qmp,server,nowait" \
    -fw_cfg name=opt/mpireos/ci,string=1 \
    -usb -device usb-tablet \
    -nic user,model=virtio-net-pci &
qemu=$!
trap 'kill $qemu $mock_ai 2>/dev/null || true' EXIT

source "$(dirname "$0")/qemu-screenshot.sh"
screenshot() { qemu_screenshot "$monitor" "$shot"; }
# Types text into the VM, one key at a time (letters, digits, space, ? and .).
type_text() {
    local text="$1" ch i
    for ((i = 0; i < ${#text}; i++)); do
        ch="${text:i:1}"
        case "$ch" in
            " ") qemu_key "$monitor" spc ;;
            "?") qemu_key "$monitor" shift-slash ;;
            ".") qemu_key "$monitor" dot ;;
            [A-Z]) qemu_key "$monitor" "shift-${ch,,}" ;;
            *) qemu_key "$monitor" "$ch" ;;
        esac
        sleep 0.15
    done
}

for ((t = 0; t < timeout; t += 5)); do
    if grep -q MPIREOS_DESKTOP_OK "$log" && grep -q MPIREOS_SETUP_OK "$log"; then
        echo "PASS: desktop and installer started after ~${t}s"
        grep -a MPIREOS_SETUP_LOG "$log" || true
        screenshot
        # Close the installer (Alt+F4) to see the desktop behind it.
        qemu_key "$monitor" alt-f4
        sleep 8
        qemu_screenshot "$monitor" "${shot%.ppm}-desktop.ppm"
        # The boot check then opens an app (Konsole and Dolphin, on frosted glass) to show window styling.
        for ((w = 0; w < 120; w += 5)); do
            grep -q MPIREOS_APP_OPENED "$log" && break
            sleep 5
        done
        grep -a MPIREOS_APP "$log" || true
        qemu_screenshot "$monitor" "${shot%.ppm}-app.ppm"
        # Then the boot check shows a notification, quick settings, and the
        # notification list; each gets a screenshot. Finally the launcher, opened
        # with Alt+Space (the real shortcut), and a search typed into it.
        wait_for() {
            for ((w = 0; w < 90; w += 2)); do grep -q "$1" "$log" && return 0; sleep 2; done
            echo "note: $1 not seen"; return 1
        }
        wait_for MPIREOS_NOTIFY_SHOWN && qemu_screenshot "$monitor" "${shot%.ppm}-notify.ppm"
        wait_for MPIREOS_QUICK_SHOWN && { sleep 2; qemu_screenshot "$monitor" "${shot%.ppm}-quick.ppm"; }
        wait_for MPIREOS_CENTER_SHOWN && { sleep 2; qemu_screenshot "$monitor" "${shot%.ppm}-center.ppm"; }
        if wait_for MPIREOS_PANELS_DONE; then
            sleep 3
            # The system tray: the test apps' icons sit left of MpireOS's own.
            tray="${shot%.ppm}-tray.ppm"
            qemu_screenshot "$monitor" "$tray"
            # Right-click the Sync app's icon (found by its color) for its menu,
            # then open the Speed Limit submenu.
            if xy="$(qemu_find_color "$tray" 5B8DEF 30)"; then
                qemu_click "$qmp" ${xy% *} ${xy#* } right "$tray"
                sleep 3
                qemu_screenshot "$monitor" "${shot%.ppm}-tray-menu.ppm"
                for k in down down down ret; do qemu_key "$monitor" "$k"; sleep 0.4; done
                sleep 2
                qemu_screenshot "$monitor" "${shot%.ppm}-tray-submenu.ppm"
                qemu_key "$monitor" esc
            else
                echo "note: the Sync tray icon is not in the top bar"
            fi
            sleep 2
            # Universal search with Meta+Space: a file, then a conversion.
            qemu_key "$monitor" meta_l-spc
            sleep 3
            qemu_screenshot "$monitor" "${shot%.ppm}-universal.ppm"
            for k in r e p o r t; do qemu_key "$monitor" "$k"; sleep 0.3; done
            sleep 3
            qemu_screenshot "$monitor" "${shot%.ppm}-universal-files.ppm"
            for _ in r e p o r t; do qemu_key "$monitor" backspace; sleep 0.2; done
            for k in 1 0 spc k m spc i n spc m i l e s; do qemu_key "$monitor" "$k"; sleep 0.3; done
            sleep 2
            qemu_screenshot "$monitor" "${shot%.ppm}-universal-convert.ppm"
            qemu_key "$monitor" esc
            sleep 2
            # Alt+Space (KRunner's shortcut) opens universal search too.
            qemu_key "$monitor" alt-spc
            sleep 3
            for k in s e t t; do qemu_key "$monitor" "$k"; sleep 0.3; done
            sleep 2
            qemu_screenshot "$monitor" "${shot%.ppm}-search.ppm"
            qemu_key "$monitor" esc
            # The AI: a question typed into universal search goes to the
            # assistant, answered by the model server found on the network.
            if grep -q MPIREOS_AI_READY "$log"; then
                sleep 2
                qemu_key "$monitor" meta_l-spc
                sleep 3
                type_text "how do I take a screenshot?"
                sleep 2
                qemu_screenshot "$monitor" "${shot%.ppm}-ai-search.ppm"
                qemu_key "$monitor" ret
                sleep 2
                qemu_screenshot "$monitor" "${shot%.ppm}-ai-streaming.ppm"
                sleep 8
                qemu_screenshot "$monitor" "${shot%.ppm}-ai-answer.ppm"
                # A follow-up, typed into the assistant itself.
                type_text "thanks"
                qemu_key "$monitor" ret
                sleep 6
                qemu_screenshot "$monitor" "${shot%.ppm}-ai-followup.ppm"
                qemu_key "$monitor" esc
                sleep 2
                # Meta+A opens the assistant too.
                qemu_key "$monitor" meta_l-a
                sleep 3
                qemu_screenshot "$monitor" "${shot%.ppm}-ai-shortcut.ppm"
                qemu_key "$monitor" esc
                sleep 2
                # AI settings, found by searching for "ai".
                qemu_key "$monitor" meta_l-spc
                sleep 3
                type_text "ai"
                sleep 2
                qemu_key "$monitor" ret
                sleep 4
                qemu_screenshot "$monitor" "${shot%.ppm}-ai-settings.ppm"
                qemu_key "$monitor" esc
            else
                echo "note: mpire-ai did not get ready"
            fi
            grep -a MPIREOS_AI "$log" || true
        fi
        # The dock hides itself; pushing the pointer against the bottom edge brings it back.
        sleep 3
        qemu_screenshot "$monitor" "${shot%.ppm}-dock-hidden.ppm"
        # usb-tablet is absolute (0-32767 on each axis): bottom center of the screen.
        qemu_pointer "$qmp" 16384 30000
        qemu_pointer "$qmp" 16384 32767
        sleep 2
        qemu_screenshot "$monitor" "${shot%.ppm}-dock-shown.ppm"
        # Right-click on the desktop opens its menu; "Change wallpaper..." opens
        # the picker, where Lagoon is picked and Done closes it. Positions are
        # for the 1280x800 screen and match tools/preview.py at that size:
        # the menu opens at the pointer, the picker sits 54 px from the top.
        ref="${shot%.ppm}-dock-shown.ppm"
        qemu_pointer "$qmp" 16384 16384
        sleep 2
        qemu_click "$qmp" 500 260 right "$ref"
        sleep 2
        qemu_screenshot "$monitor" "${shot%.ppm}-desktop-menu.ppm"
        qemu_click "$qmp" 580 284 left "$ref"
        sleep 4
        qemu_screenshot "$monitor" "${shot%.ppm}-wallpaper-picker.ppm"
        qemu_click "$qmp" 730 228 left "$ref"
        sleep 3
        qemu_screenshot "$monitor" "${shot%.ppm}-wallpaper-lagoon.ppm"
        qemu_click "$qmp" 956 721 left "$ref"
        sleep 3
        qemu_screenshot "$monitor" "${shot%.ppm}-desktop-lagoon.ppm"
        # Auto-hide the dock: off (the third menu row), then the dock stays up.
        qemu_click "$qmp" 500 260 right "$ref"
        sleep 2
        qemu_click "$qmp" 580 356 left "$ref"
        sleep 2
        qemu_screenshot "$monitor" "${shot%.ppm}-menu-dock-pinned.ppm"
        qemu_key "$monitor" esc
        qemu_click "$qmp" 900 200 left "$ref"
        sleep 4
        qemu_screenshot "$monitor" "${shot%.ppm}-dock-pinned.ppm"
        # Frosted-glass app windows over a brighter wallpaper (Lagoon, picked
        # above): Konsole, then Files (Dolphin), opened from universal search.
        for app in konsole dolphin; do
            qemu_key "$monitor" meta_l-spc
            sleep 3
            type_text "$app"
            sleep 2
            qemu_key "$monitor" ret
            sleep 12
        done
        qemu_screenshot "$monitor" "${shot%.ppm}-glass-apps.ppm"
        grep -a -e MPIREOS_SPLASH -e MPIREOS_NOTIFY -e MPIREOS_QUICK -e MPIREOS_CENTER -e MPIREOS_SHORTCUT -e MPIREOS_TRAY -e MPIREOS_AI "$log" || true
        exit 0
    fi
    if grep -q -e MPIREOS_DESKTOP_FAIL -e MPIREOS_SETUP_FAIL "$log"; then
        echo "FAIL: the desktop or the installer did not start"
        grep -a MPIREOS_ "$log" || true
        screenshot
        exit 1
    fi
    if ! kill -0 $qemu 2>/dev/null; then
        echo "FAIL: QEMU exited early"
        tail -n 50 "$log"
        exit 1
    fi
    sleep 5
done
echo "FAIL: timed out after ${timeout}s"
screenshot
tail -n 80 "$log"
exit 1
