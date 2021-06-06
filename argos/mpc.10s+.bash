#!/bin/bash

HOST=<tbd>
MPC="mpc -h $HOST"
VLC="vlc http://$HOST:8001/"
SNAPCLIENT="snapclient --user snapclient:audio -h $HOST"


# various methods to check whether mpd is reachable at all
# if ping -c 1 -W 0.2 $HOST > /dev/null 2>&1 
if [[ $( dig +short $HOST | wc -l ) -gt 0 ]]
then
  NET=ok
else
  NET=notok
fi

if [[ "$NET" == "ok" ]]
then
  buttontext=$( $MPC status | tr -d "&*" | head -1 )
  if echo $buttontext | egrep ^volume > /dev/null
  then
    buttontext=mpd
  fi
else
  buttontext="mpd offline"
fi

if [[ ${#buttontext} -ge 40 ]]
then
  shortbuttontext=...$( echo $buttontext | egrep -o '.{1,38}$' )
  echo $shortbuttontext
  echo "---"
  echo "$buttontext"
else
  echo "$buttontext"
  echo "---"
fi

for i in pause play stop next prev 
do
  echo "$i | terminal=false bash='$MPC $i'"
done
if [[ "${buttontext:0:3}" != "mpd" ]]
then
  $MPC status | tail -n +2 
  echo "$VLC | terminal=false bash='$VLC'" 
  echo "$SNAPCLIENT | terminal=true bash='killall snapclient; sleep 1; $SNAPCLIENT'" 
fi
echo "sonata | terminal=false bash=sonata"

