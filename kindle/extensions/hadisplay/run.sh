#!/bin/sh
# Shows the Home Assistant Kindle render full-screen, refreshing on a timer.
URL=http://192.168.86.244:5000/
INTERVAL=300     # seconds between refreshes
FULL_EVERY=6     # full black/white flash every N draws to clear ghosting
PID=/tmp/hadisplay.pid

stop_loop() {
  [ -f $PID ] && kill "$(cat $PID)" 2>/dev/null
  rm -f $PID
}

case "$1" in
start)
  stop_loop
  lipc-set-prop com.lab126.powerd preventScreenSaver 1
  # ponytail: draws over the stock UI instead of stopping it; tap screen to get the UI back.
  # If UI elements keep reappearing between draws, stop lab126_gui here (and start it in stop).
  (
    n=0
    while :; do
      sleep 3   # let KUAL's menu close before drawing
      if wget -q -T 20 -O /tmp/hadisplay.png "$URL"; then
        if [ $((n % FULL_EVERY)) -eq 0 ]; then eips -f -g /tmp/hadisplay.png; else eips -g /tmp/hadisplay.png; fi
        n=$((n + 1))
      fi
      sleep $((INTERVAL - 3))
    done
  ) >/dev/null 2>&1 &
  echo $! > $PID
  ;;
stop)
  stop_loop
  lipc-set-prop com.lab126.powerd preventScreenSaver 0
  ;;
esac
