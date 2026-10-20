#!/bin/sh
# Shows the Home Assistant Kindle render full-screen, refreshing on a timer.
URL=http://192.168.86.244:5000/
INTERVAL=120     # seconds between refreshes
NIGHT_START=23   # no refreshes from 11 PM...
NIGHT_END=6      # ...until 6 AM
export TZ=PST8PDT,M3.2.0,M11.1.0   # don't trust the Kindle's own zone setting
FULL_EVERY=30    # full black/white flash every N draws to clear ghosting
DIR=/mnt/us/extensions/hadisplay
PID=/tmp/hadisplay.pid

# Sleep (suspended) for $1 seconds, woken by the RTC alarm.
# Falls back to a plain sleep if the alarm can't be set or suspend fails.
nap() {
  set=0
  for a in /sys/class/rtc/rtc*/wakealarm; do
    echo 0 > "$a" 2>/dev/null && echo "+$1" > "$a" 2>/dev/null && set=1
  done
  if [ $set = 1 ] && echo mem > /sys/power/state; then :; else sleep "$1"; fi
}

stop_loop() {
  [ -f $PID ] && kill "$(cat $PID)" 2>/dev/null
  rm -f $PID
}

case "$1" in
start)
  stop_loop
  # Own session, so the loop survives KUAL exiting and the UI stopping.
  setsid "$DIR/run.sh" loop </dev/null >/dev/null 2>&1 &
  ;;
loop)
  echo $$ > $PID
  exec >"$DIR/log.txt" 2>&1
  set -x
  lipc-set-prop com.lab126.powerd preventScreenSaver 1
  # Stop the Kindle UI so the library can't redraw over the image.
  # To get the normal Kindle back, hold the power button to restart it.
  sleep 2
  stop lab126_gui
  sleep 3
  sync
  n=0
  while :; do
    # Frontlight off (repeated each pass in case powerd restores it).
    lipc-set-prop com.lab126.powerd flIntensity 0
    for b in /sys/class/backlight/*/brightness; do echo 0 > "$b"; done
    # Wait up to 60s for Wi-Fi in case it dropped with the UI.
    i=0
    while [ "$(lipc-get-prop com.lab126.wifid cmState)" != CONNECTED ] && [ $i -lt 30 ]; do
      lipc-set-prop com.lab126.cmd wirelessEnable 1
      sleep 2; i=$((i + 1))
    done
    BATT="batteryLevel=$(lipc-get-prop com.lab126.powerd battLevel)&isCharging=$(lipc-get-prop com.lab126.powerd isCharging)"
    if wget -q -T 20 -O /tmp/hadisplay.png "$URL?$BATT"; then
      if [ $((n % FULL_EVERY)) -eq 0 ]; then eips -f -g /tmp/hadisplay.png; else eips -g /tmp/hadisplay.png; fi
      n=$((n + 1))
    fi
    sync   # hard restarts otherwise lose the log
    sleep 3   # let the e-ink finish drawing before suspending
    h=$(date +%H); h=${h#0}
    if [ $h -ge $NIGHT_START ] || [ $h -lt $NIGHT_END ]; then
      m=$(date +%M); m=${m#0}
      nap $(( ((NIGHT_END - h + 24) % 24) * 3600 - m * 60 ))
    else
      nap $INTERVAL
    fi
  done
  ;;
stop)
  stop_loop
  lipc-set-prop com.lab126.powerd preventScreenSaver 0
  start lab126_gui
  ;;
esac
