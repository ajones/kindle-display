#!/bin/sh
# Shows the Home Assistant Kindle render full-screen, refreshing on a timer.
URL=http://192.168.86.244:5000/
INTERVAL=60      # seconds between refreshes
FULL_EVERY=30    # full black/white flash every N draws to clear ghosting
PID=/tmp/hadisplay.pid

stop_loop() {
  [ -f $PID ] && kill "$(cat $PID)" 2>/dev/null
  rm -f $PID
}

case "$1" in
start)
  stop_loop
  lipc-set-prop com.lab126.powerd preventScreenSaver 1
  # Stop the Kindle UI so the library can't redraw over the image.
  # To get the normal Kindle back, hold the power button to restart it.
  (
    sleep 2   # let KUAL finish before pulling the UI out from under it
    stop lab126_gui
    n=0
    while :; do
      if wget -q -T 20 -O /tmp/hadisplay.png "$URL"; then
        if [ $((n % FULL_EVERY)) -eq 0 ]; then eips -f -g /tmp/hadisplay.png; else eips -g /tmp/hadisplay.png; fi
        n=$((n + 1))
      fi
      sleep $INTERVAL
    done
  ) >/dev/null 2>&1 &
  echo $! > $PID
  ;;
stop)
  stop_loop
  lipc-set-prop com.lab126.powerd preventScreenSaver 0
  start lab126_gui
  ;;
esac
