#!/bin/bash

SNAPSERVER=<tbd>
SNAPPORT=1705

# echo $0 $* >> /tmp/argosdebug

usage () {

  echo "" 
  echo "Usage:"
  echo "" 
  echo "  $0 : creates output usable as argos menu"
  echo "  $0 -i <id> -v <volume> : sets the volume"
  echo "" 

}

snaprpc () {

  #add a space at the end of the line (wtf?)
  RPCCALL="$1 "

  echo "$RPCCALL" | nc $SNAPSERVER $SNAPPORT | head -1

}

getstatus () {

  REQUEST='{"id":1,"jsonrpc":"2.0","method":"Server.GetStatus"}'
  snaprpc "$REQUEST"

}

showmenu () {
  echo "snapcast"
  echo "---"
  REPLY=$( getstatus ) 
  numgroups=$( echo $REPLY | jq '.result.server.groups | length' ) 
  currentgroup=0
  while [[ $currentgroup -lt $numgroups ]]
  do
    numclients=$(   echo $REPLY | jq ".result.server.groups[$currentgroup].clients | length" )
    numconnected=$( echo $REPLY | jq ".result.server.groups[$currentgroup].clients | map ( select (.connected == true) ) | length " )
    if [[ $numconnected -gt 0 ]]
    then
      echo "GROUP $currentgroup ($numconnected of $numclients)"
    fi
    currentclient=0
    while [[ $currentclient -lt $numclients ]]
    do
      ID=$(        echo $REPLY | jq ".result.server.groups[$currentgroup].clients[$currentclient].id" | sed -e 's/"//g' )
      HOST=$(      echo $REPLY | jq ".result.server.groups[$currentgroup].clients[$currentclient].host.name" | sed -e 's/"//g' ) 
      CONNECTED=$( echo $REPLY | jq ".result.server.groups[$currentgroup].clients[$currentclient].connected"             )
      VOLUME=$(    echo $REPLY | jq ".result.server.groups[$currentgroup].clients[$currentclient].config.volume.percent" ) 
      # echo "XX-CURRENTCLIENT $currentclient ID $ID HOST $HOST CONNECTED $CONNECTED VOLUME $VOLUME"
      if [[ "$CONNECTED" == "true" ]]
      then
        echo $HOST $VOLUME
        MAXPRINTED=false
        MINPRINTED=false
        for DELTA in +100 +64 +32 +16 +8 +4 +2 +1 -1 -2 -4 -8 -16 -32 -64 -100
        do
          newvol=$(( $VOLUME $DELTA ))
          moreorless=${DELTA:0:1}
          if [[ $newvol -ge 100 ]]
          then
            if [[ $MAXPRINTED != true ]]
            then 
              newvol=100
              echo "-- $moreorless $( printf '%02d' ${newvol} ) $HOST (MAX) | terminal=false bash='$0 -i $ID -v $newvol'"
              MAXPRINTED=true
            fi
          elif [[ $newvol -le 0 ]]
          then
            if [[ $MINPRINTED != true ]]
            then
              newvol=0
              echo "-- $moreorless $( printf '%02d' ${newvol} ) $HOST (MIN) | terminal=false bash='$0 -i $ID -v $newvol'"
              MINPRINTED=true
            fi
          else
            echo "-- $moreorless $( printf '%02d' ${newvol} ) $HOST ($DELTA) | terminal=false bash='$0 -i $ID -v $newvol'"
          fi
        done
      fi
      currentclient=$(( currentclient + 1 )) 
    done
    currentgroup=$(( currentgroup + 1 ))
  done
}

setvolume () {

  ID=$1
  VOL=$2

  if [[ $VOL -gt 100 ]] 
  then
    VOL=100
  elif [[ $VOL -lt 0 ]]
  then
    VOL=0
  fi

  # echo "setting volume of $ID to $VOL"

  REQUEST_P1='{"id":8,"jsonrpc":"2.0","method":"Client.SetVolume","params":{"id":"'
  REQUEST_P2='","volume":{"muted":false,"percent":'
  REQUEST_P3='}}}'

  REQUEST="${REQUEST_P1}${ID}${REQUEST_P2}${VOL}${REQUEST_P3}"

  REPLY=$( snaprpc "$REQUEST" )

}

# DEBUGs
# getstatus
# REPLY=$( getstatus ) 
#echo $REPLY | jq
#echo $REPLY | jq '.result.server.groups[].clients | length'
#sizestatus=$( echo $REPLY | jq '.result.server.groups | length' )
# exit 1

if [[ $# -eq 0 ]]
then
  showmenu
else
  while getopts i:v: option
  do
    case $option in 
      i) SNAPCLIENTID="$OPTARG" ;;
      v) NEWVOLUME="$OPTARG" ;;
      *) usage ;;
    esac
 done
 if [[ -z "$SNAPCLIENTID" || -z "$NEWVOLUME" ]]
 then
   usage
 else
   setvolume "$SNAPCLIENTID" "$NEWVOLUME"
 fi
fi

