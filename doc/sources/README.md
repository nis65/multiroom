# Sources

In my first attempt, I invested quite some time into transporting local sources (line in, bluetooth) from a satellite node to the central `snapserver` using `icecast`. It worked, but was quite unhandy to work with and I almost never used it. 

But what I use quite often is to connect to a satellite with bluetooth and playing the sound directly there (i.e. only on that node without transporting it to the snapserver). So I currently use a *local shortcut* that sends the bluetooth (and/or line in) audio directly to the local ALSA sink. 

## Line In

On `snapserver` node

* to first loopback (selectable by `mpd`) 
* to second loopback (or directly to snapserver if newer version available)

On all nodes

* to hifiberry `dmix` (shortcut)

## Bluetooth

Most tricky part:

* Needs automatic pairing 
* bluetooth stack is open for surprises on updates
* `bluealsa` works perfectly, but you need to know the MAC-Adress of the bluetooth device to address the ALSA port



