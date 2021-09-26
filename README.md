# multiroom

Combine all your existing audio hardware to a multiroom audio system using 
[raspberry pis](https://en.wikipedia.org/wiki/Raspberry_Pi#Specifications) and 
[hifiberry HATs](https://www.hifiberry.com). If you miss something, buy only
what you need.

## Architecture
### Opaque Box
#### Audio Sinks
* line out
* 4-8Ohm loudspeakers, 3W or 60W
* current multiroom: all sinks synchronous, each sink with individual volume control
* future multiroom: split in multiple multiroom segments with individual audio sources

#### Audio Sources
* line in
* bluetooth 
* digital library (FLAC, ...)
* internet readio

#### Source switching (and mixing?)
* yes: with mpd 
* no: mix all sources unconditionally to output
* future: support mixing 

### Transparent Box

#### Precondition

You have the needed hardware available and assembled, you know how to make a raspberry pi bootable, how to 
change basic configurations like disabling internal sound and enabling the raspberry pi driver etc. Each 
raspberry pi is connected to your LAN or WLAN and you can login using `ssh`.

#### Basics

The whole audio system uses a single audio format. I decided to 
go for audio cd format **44100Hz/16bit/stereo**, but your mileage 
my vary. 

Furthermore, there are the following limitations/requirements:

* Audio conversions should be minimized to maximize audio quality.
* Each sound card has a global clock / audio format, i.e. you cannot capture a stream at some bit rate and playback a (possibly different) 
  stream at a different bitrate. This seems to be a general HW limitation.
* Using `aloop` virtual soundcards and `dmix` / `dsnoop` devices, it is easy to mix in / fan out ALSA audio streams, provided they all have the same audio format.

From a architectural point of view, each node of my multiroom audio system has the following basic ALSA infrastructure:

* loopback soundcard loaded (alsa index 1 so that hifiberry stays on 0)
* first loopback from dmix0 to dsnoop1 used to "mix" all sources 
* second loopback from dmix 1 to dsnoop2 used to "mix" all sinks to handover to snapserver. Might not be needed any more as newer versions of snapserver seem to have the builtin capability for mixing multiple sources.

Hint: There are some technical limitation in the ALSA stack: 

* `alsaloop` seems not to work with `dmix`/`dsnoop` devices. So I use a lot of `arecord | aplay` pipelines instead to copy audiodata streams.
* when using `.wav` as output format, both `aplay` and `arecord` stop after a bit more than 3 hours. This is the `2GB` limit of `.wav` files which applies even when using `stdout`/`stdin` and not a regular file as sink/source... So you need to have `-t raw` on every `arecord`/`aplay` command.

#### Audio Sinks

It may sound strange to start with the sinks, i.e. putting the cart before the horse. But this is actually the
better way to look at it: Output handling is much simpler compared to input handling and 
you need to hear something anyway to debug all audio bugs you might encounter on your journey.  In addition, the 
core requirement **multiroom** is about the sink part only.

* lineout (Stereo Cinch)
  * useful to connect your existing hifi amp or an active loudspeaker (i.e. with builtin amp)
  * do not use the raspberry on board audio if possible
  * my own experience: any [hifiberry HAT](https://www.hifiberry.com) with `DAC` in its name
* 4-8 ohms loudspeaker (four wires)
  * my own experience any [hifiberry HAT](https://www.hifiberry.com) with `Amp` in its name
* do **not** use bluetooth for sinks, as the latency of bluetooth is not predictable and this would ruin the multiroom experience

Available sinks: 

* ALSA: dmix of hifiberry DAC/Amp
* snapcast: snapclient
  * current: needs static configuration of snapserver
  * future: switchable for multiple segments? autofind?

More details to be found [here](doc/sinks/README.md)

#### Audio Sources

* line in (3.5 mm jack stereo)
  * useful to feed REC OUT from your hifi amp (or from your mobile) to the multiroom system
  * my own experience: any [hifiberry HAT](https://www.hifiberry.com) with `ADC` in its name
* bluetooth (A2DP)
  * any [raspberry pi](https://en.wikipedia.org/wiki/Raspberry_Pi#Specifications) with builtin bluetooth. External dongles might work too, but I have not tested this. This is the most tricky thing to setup properly.
* USB soundcard
  * e.g. record player with builtin USB interface

More details to be found [here](doc/sources/README.md)

#### Source Switching 

If you want to control what output is played to your rooms, you need an application like `mpd` and configure `mpd` to output it's 
music stream in 44100Hz/16bit/stereo to the second loopback that feeds snapserver. In addition, mpd can play IP-radio and
local music libraries. 

If you don't need this (either you have an external mixer or you simply prefer to e.g. stop mpd when you switch to bluetooth), all sources 
get mixed to the second loopback dmix unconditionally.

More details to be found [here](docs/controls/README.md)


## Motivation

I am fascinated by open source. I am addicted to the music I like. The first time I saw multiroom
audio was as a 14 year old in a flat with speakers in every room. They were all 
connected via flushmounted (unter Putz) cables to the central hifi amp.

Years later, I started to stream audio over WLAN. But as I was using the MPD http output, I had multiroom,
but not synchronous. Hurting my ears whenever changing from the kitchen to the living room.

In 2018, I started with rasperry pi, hifiberry and snapcast. Boooom! True synchronous audio with 
individual volume in every room. However, the approach was quite bottom up because all interfaces
were new and I actually had some requirements that forced me to learn even more...

This is now my 2nd approach to document what I learned, hopefully in a much more structured way
than the [first attempt](doc/legacy/2021_README.md).



