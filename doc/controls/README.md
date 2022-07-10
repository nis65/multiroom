
# Controls

## None (mix unconditionally)

In a simple setup, it might be enough to connect all sources to the loopback `dmix` device `dmix:CARD=Loopback,DEV=0` and let snapserver pick up the audio from there. The user has to ensure that only one source is playing audio at the same time. Otherwise, both will be snapcasted to all rooms simultaneously...

## `mpd`

### Sources
* IP sources
  * Internet Radio
  * FLAC / mp3 library on a SMB share
* ALSA sources
  * This enables you to create more complex setups: Instead of mixing all sources unconditionally to the snapserver, you could decide not to connect them at all in the beginning, but select them explicitly as audio source in `mpd`. You might even make use of a second loopback device (that can be selected in `mpd` as source again). I had that initially, but considered it not to be handy enough. And it does not relieve the user from anything, it just adds one additional level of complexity. ymmv :smile:.

## `spotify`

The integration with `raspotify` is similar to mpd, the only thing you need to configure on your spotify client is a new loudspeaker.

### Sinks
The most important piece of software to control are the snapserver sinks: What room plays audio, at what volume? Since `snapweb` is part of snapcast, you just need a browser pointing to the snapserver device port 1780 and you have all you need.
