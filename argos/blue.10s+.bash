#!/bin/bash

LOGGER="/usr/bin/logger -t $0"

# list of devices, only shown when manually paired before
MYDEVICES="schlaf|bad|infinity|chuchi|wohnen|TP-LINK_Music"

usage () {
  echo "" 
  echo "Usage:"
  echo ""
  echo "  $0 : creates output usable as argos menu"
  echo "  $0 -c <id> : connects to bluetooth MAC <id>"
  echo "  $0 -d <id> : disconnects from bluetooth MAC <id>"
  echo "  $0 -x      : disconnects from all known bluetooth MACs"
  echo ""
  exit 1
}

connect () {
  BT_DEV=$1

  (
  bluetoothctl remove $BT_DEV 

  TEMPDIR=$( mktemp -d /tmp/bluetmp.XXXXXX )
  cmdfifo=$TEMPDIR/bluein
  resultfifo=$TEMPDIR/blueout
  
  mkfifo $cmdfifo
  mkfifo $resultfifo
  
  # start bluetoothctl in background
  
  bluetoothctl < $cmdfifo > $resultfifo &
  BLUEPID=$!
  
  sleep 10000 > $cmdfifo &
  SLEEPID=$!
  
  (
  STATE=starting
  cat $resultfifo | while read line
  do
    $LOGGER "$STATE - $line"
    case $STATE in
      starting ) if echo "$line" | grep  "scan on$" > /dev/null
                 then
                   $LOGGER "Start scanning for $BT_DEV"
                   STATE=scanning
                 fi
                 ;;
      scanning ) if echo "$line" | grep "$BT_DEV" > /dev/null
                 then
                   STATE=found
                   # echo "scan off" > $cmdfifo
                   kill $SLEEPID
                 fi
                 ;;
    esac
  done
  $LOGGER "stopped reading $resultfifo"
  ) &
  
  echo "scan on" > $cmdfifo
  wait $BLUEPID
  
  rm -rf $TEMPDIR

  bluetoothctl trust $BT_DEV | $LOGGER
  bluetoothctl pair $BT_DEV | $LOGGER
  bluetoothctl --agent NoInputNoOutput connect $BT_DEV | $LOGGER
  ) > /dev/null
}

disconnect () {
  bt-device -d $1

}

disconnectall () {
  bt-device -l | grep -v "Added devices:" | egrep "$MYDEVICES"| \
    sed -e "s/^\([^ ]*\) (\([A-F0-9:]*\))$/\1 \2/" | sort | while read name id
  do
    bt-device -d $id
  done
}

showmenu () {
  echo "blue"
  echo "---"
  bt-device -l | grep -v "Added devices:" | egrep "$MYDEVICES"| \
    sed -e "s/^\([^ ]*\) (\([A-F0-9:]*\))$/\1 \2/" | sort | while read name id
  do
    echo "connect $name | terminal=false bash='$0 -x ; $0 -c $id'"
  done
  echo "disconnect all | terminal=false bash='$0 -x'"
}

if [[ $# -eq 0 ]]
then
  showmenu
else
  while getopts c:d:x option
  do
    case $option in 
      c) DO=CONNECT; BLUEID="$OPTARG";;
      d) DO=DISCONNECT; BLUEID="$OPTARG";;
      x) DO=DISCONNECTALL ;;
      *) usage ;;
    esac
 done
 if [[ $DO == CONNECT ]]
 then
   connect $BLUEID
 elif [[ $DO == DISCONNECT ]]
 then
   disconnect $BLUEID
 else
   disconnectall 
 fi
fi


