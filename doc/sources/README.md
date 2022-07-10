# Sources

In my first attempt, I invested quite some time into transporting local sources (line in, bluetooth) from a satellite node to the central `snapserver` using `icecast`. It worked, but was quite unhandy to work with and I almost never used it. As the [ansible implementation](Daenou/ansible-multiroom-audio) supports a snpaserver on more than one node and each client running as many snapclients as there are snapservers in the network, I can use snapcast for all audio network transport use cases and don't need `icecast` any more.

But what I use quite often is to connect to a satellite with bluetooth and playing the sound directly there (i.e. only on that node without transporting it to the snapserver). So I currently use a *local shortcut* that sends the bluetooth (and/or line in) audio directly to the local ALSA sink.

## Line In

Line In can get connected

* on **all** nodes: to the hifiberry `dmix` device where it is output directly to the local speakers and cannot be distributed further
* on a `snapserver` node: to the alsa loopback device where it is picked up (and distributed) from snapserver

## Bluetooth

Most tricky part:

* Needs automatic pairing
* bluetooth stack is open for surprises: on updates, bad bluetooth implementations stack on (mobile) clients
* `bluealsa` works perfectly, but you need to know the MAC-Adress of the bluetooth device to address the ALSA port
