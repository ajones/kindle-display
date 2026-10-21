#!/bin/sh
# Shows the Home Assistant Kindle render full-screen, refreshing on a timer.
URL=http://192.168.86.244:5000/
DASH_EVERY=1800     # seconds between dashboard downloads
COMMUTE_EVERY=180   # ...during the commute window (train times)
COMMUTE_DAYS=12345  # weekdays (date +%u, 1=Mon)
COMMUTE_START=6     # 6 AM...
COMMUTE_END=9       # ...to 9 AM
NIGHT_START=23   # no downloads from 11 PM...
NIGHT_END=6      # ...until 6 AM (the clock keeps ticking)
export TZ=PST8PDT,M3.2.0,M11.1.0   # don't trust the Kindle's own zone setting
FULL_EVERY=6     # full black/white flash every N dashboard draws to clear ghosting
CLOCK_X=40       # where clock/HHMM.png goes; must match make-clock.py BOX
CLOCK_Y=40
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
  due=0   # epoch time of the next dashboard download
  while :; do
    # Frontlight off (repeated each pass in case powerd restores it).
    lipc-set-prop com.lab126.powerd flIntensity 0
    for b in /sys/class/backlight/*/brightness; do echo 0 > "$b"; done
    h=$(date +%H); h=${h#0}
    if [ "$(date +%s)" -ge $due ] && [ $h -ge $NIGHT_END ] && [ $h -lt $NIGHT_START ]; then
      set -x
      # Wait up to 60s for Wi-Fi; it's switched off between downloads.
      i=0
      while [ "$(lipc-get-prop com.lab126.wifid cmState)" != CONNECTED ] && [ $i -lt 30 ]; do
        lipc-set-prop com.lab126.cmd wirelessEnable 1
        sleep 2; i=$((i + 1))
      done
      BATT="batteryLevel=$(lipc-get-prop com.lab126.powerd battLevel)&isCharging=$(lipc-get-prop com.lab126.powerd isCharging)"
      # -S logs the server's Date header, to compare with ours for clock drift.
      if wget -q -S -T 20 -O /tmp/hadisplay.png "$URL?$BATT"; then
        if [ $((n % FULL_EVERY)) -eq 0 ]; then eips -f -g /tmp/hadisplay.png; else eips -g /tmp/hadisplay.png; fi
        n=$((n + 1))
      fi
      date -u
      lipc-set-prop com.lab126.cmd wirelessEnable 0
      if [ $h -ge $COMMUTE_START ] && [ $h -lt $COMMUTE_END ] && case $COMMUTE_DAYS in *$(date +%u)*) true;; *) false;; esac; then
        due=$(($(date +%s) + COMMUTE_EVERY))
      else
        due=$(($(date +%s) + DASH_EVERY))
      fi
      sync   # hard restarts otherwise lose the log
      set +x
    fi
    # Draw the clock over the dashboard's; region-only flash every 15 min.
    m=$(date +%M); m=${m#0}
    if [ $((m % 15)) -eq 0 ]; then f=-f; else f=; fi
    eips $f -g "$DIR/clock/$(date +%H%M).png" -x $CLOCK_X -y $CLOCK_Y >/dev/null
    sleep 2   # let the e-ink finish drawing before suspending
    s=$(date +%S); s=${s#0}
    nap $((60 - s))
  done
  ;;
stop)
  stop_loop
  lipc-set-prop com.lab126.powerd preventScreenSaver 0
  start lab126_gui
  ;;
esac
