#!/bin/bash

function wait_emulator_to_be_ready () {
  boot_completed=false
  while [ "$boot_completed" == false ]; do
    status=$(adb wait-for-device shell getprop sys.boot_completed | tr -d '\r')
    echo "Boot Status: $status"

    if [ "$status" == "1" ]; then
      boot_completed=true
    else
      sleep 1
    fi      
  done
}

function change_language_if_needed() {
  if [ ! -z "${LANGUAGE// }" ] && [ ! -z "${COUNTRY// }" ]; then
    wait_emulator_to_be_ready
    echo "Language will be changed to ${LANGUAGE}-${COUNTRY}"
    adb root && adb shell "setprop persist.sys.language $LANGUAGE; setprop persist.sys.country $COUNTRY; stop; start" && adb unroot
    echo "Language is changed!"
  fi
}

function install_google_play () {
  wait_emulator_to_be_ready
  echo "Google Play Service will be installed"
  adb install -r "/root/google_play_services.apk"
  echo "Google Play Store will be installed"
  adb install -r "/root/google_play_store.apk"
}

function disable_animation () {
  # To improve performance
  adb shell "settings put global window_animation_scale 0.0"
  adb shell "settings put global transition_animation_scale 0.0"
  adb shell "settings put global animator_duration_scale 0.0"
}

function enable_proxy_if_needed () {
  if [ "$ENABLE_PROXY_ON_EMULATOR" = true ]; then
    if [ ! -z "${HTTP_PROXY// }" ]; then
      if [[ $HTTP_PROXY == *"http"* ]]; then
        protocol="$(echo $HTTP_PROXY | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        proxy="$(echo ${HTTP_PROXY/$protocol/})"
        echo "[EMULATOR] - Proxy: $proxy"

        IFS=':' read -r -a p <<< "$proxy"

        echo "[EMULATOR] - Proxy-IP: ${p[0]}"
        echo "[EMULATOR] - Proxy-Port: ${p[1]}"

        wait_emulator_to_be_ready
	
        echo "Enable proxy on Android emulator. Please make sure that docker-container has internet access!"
        adb root

        echo "Set up the Proxy"
        adb shell "content update --uri content://telephony/carriers --bind proxy:s:"${p[0]}" --bind port:s:"${p[1]}" --where "mcc=310" --where "mnc=260""

	echo "Install proxy certificate"
	adb push ./5bc1dc75.0 /data/misc/user/0/cacerts-added/5bc1dc75.0
	adb shell "su 0 chmod 644 /data/misc/user/0/cacerts-added/5bc1dc75.0"
	
	echo "Disable wifi"
	adb shell "su 0 svc wifi disable"
		
        adb unroot
      else
        echo "Please use http:// in the beginning!"
      fi
    else
      echo "$HTTP_PROXY is not given! Please pass it through environment variable!"
      exit 1
    fi
  fi
}

enable_proxy_if_needed
sleep 1
change_language_if_needed
sleep 1
install_google_play
disable_animation
