# multiroom

**NOTE**: This is my 2nd attempt (this was my [first attempt](doc/legacy/2021_README.md)) to document properly all manual steps needed to setup a multiroom audio system using
raspberry pi hardware and open source software only. While the documentation here is still valid, the code is partially outdated as I have switched to
automatic deployment with ansible and all new development happens [there](https://github.com/Daenou/ansible-multiroom-audio) now.

## Goal

Combine all your existing audio hardware to a multiroom audio system using
[raspberry pis](https://en.wikipedia.org/wiki/Raspberry_Pi#Specifications) and
[hifiberry HATs](https://www.hifiberry.com). If you miss something, you need to
buy it. If you buy only what you really need, you will have very good value
for money.

## Architecture
### Opaque Box
#### Audio Sinks
* line out
* 4-8Ohm loudspeakers, 3W or 60W
* all sinks synchronous, each sink with individual volume control
* bluetooth is **not** used as sink because of unpredictable latency.

#### Audio Sources
* line in
* bluetooth
* mpd / spotify / ...

#### Source switching (and mixing?)

a.k.a control what is playing. Current architecture connects all sources, that are to be distributed via snapcast to an alsa `dmix` loopback device. If multiple sources play at once, they get 'mixed' by alsa. This has two consequences:

* It is the users responsibility to play only one source at once and to feed the source with the proper signal (e.g. mpd/spotify playlist, play to bluetooth, put on a vinyl record)
* All sources must deliver the audio signal in the same format (otherwise `dmix` cannot be used).

### Transparent Box

#### Precondition

You have the needed hardware available and assembled, your raspberry pi boots, you know how to
change basic configurations like disabling internal sound and enabling the raspberry pi driver etc. Each
raspberry pi is connected to your LAN or WLAN and you can login using `ssh`. If you have local
DNS, your raspberry pi has a reasonable name.

#### Basics

We only use ALSA, e.g. no `pulseaudio` or `JACK`.

The whole audio system uses a single audio format. I decided to
go for audio cd format **44100Hz/16bit/stereo**, but your mileage
my vary.

Furthermore, there are the following limitations/requirements:

* Audio conversions should be minimized to maximize audio quality.
* Each sound card has one global clock (and audio format) at a certain moment in time, i.e. while you actually
  can capture a stream and playback a different stream at the same time, this is only possible if they have exactly
  the same bitrate and audio format. This is important because my setup sometimes uses both the source and sink of the
  same soundcard for completely independent audio streams. In addition, that said HW limitation causes the analog output
  to *crack* when you start to capture from the analog input while the output is playing.  Therefore, the output must be interrupted shortly
  before you start reading from the input.
* Using `aloop` virtual soundcards and `dmix` / `dsnoop` devices, it is easy to mix in / fan out ALSA audio streams, provided they all have the same audio format.

From an architectural point of view, each server node (there can be more than one) of my multiroom audio system has the following basic ALSA infrastructure:

* loopback soundcard loaded (and use always names and not numbers as the latter can change on reboot)
* first loopback from dmix0 to dsnoop1 used to "mix" all sources
* `snapserver` to consume the audio signal from dsnoop1 and distribute it

Each client node

* runs a local snapclient writing to `dmix` analog out
* can put additional audio signals to the local `dmix` analog out, e.g. a bluetooth input (which converts a client into a bluetooth speaker)

Hint: There are some technical limitations in the ALSA stack:

* `alsaloop` seems not to work with `dmix`/`dsnoop` devices. So I use a lot of `arecord | aplay` pipelines instead to copy audio data streams.
* when using `.wav` as output format, both `aplay` and `arecord` stop after a bit more than 3 hours. This is the `2GB` limit of `.wav` files which applies even when using `stdout`/`stdin` and not a regular file as sink/source! So you need to have `-t raw` on every `arecord`/`aplay` command.

#### Audio Sinks

It may sound strange to start with the sinks, i.e. putting the cart before the horse. But this is actually the
better way to look at it: Output handling is much simpler compared to input handling and
you need to hear something anyway to debug all audio bugs you might encounter on your journey.  In addition, the
core requirement **multiroom** is about the sink part only.

Hardware sinks:

* lineout (Stereo Cinch)
  * useful to connect your existing hifi amp or an active loudspeaker (i.e. with builtin amp)
  * do not use the raspberry on board audio if possible
  * my own experience: any [hifiberry HAT](https://www.hifiberry.com) with `DAC` in its name
* a pair 4-8 ohms loudspeaker (2x2 wires)
  * my own experience: any [hifiberry HAT](https://www.hifiberry.com) with `Amp` in its name
* do **not** use bluetooth to connect to loudspeakers, as the unpredictable latency of bluetooth would ruin the multiroom experience

Software sinks to drive the hardware directly:

* ALSA: use the `dmix` of hifiberry DAC/Amp

#### Audio Sources

Hardware Sources:

* line in (3.5 mm jack stereo)
  * useful to feed REC OUT from your hifi amp (or from your mobile) to the multiroom system
  * my own experience: any [hifiberry HAT](https://www.hifiberry.com) with `ADC` in its name
* bluetooth (A2DP)
  * any [raspberry pi](https://en.wikipedia.org/wiki/Raspberry_Pi#Specifications) with builtin bluetooth. External dongles might work too, but I have not tested this. This is the most tricky thing to setup properly.
* USB soundcard
  * e.g. record player with builtin USB interface

Software sources (like Internet Radio) are more a control issue (see below).

More details to be found [here](doc/sources/README.md)

#### Controls (source switching / mixing)

If you want to control what output is played to your rooms, you need an application like `mpd` and configure `mpd` to output it's
music stream in 44100Hz/16bit/stereo to the alsa loopback that feeds snapserver. In addition, `mpd` can play IP-radio and
local music libraries.

More details to be found [here](doc/controls/README.md)

## Motivation

I am fascinated by open source. I am addicted to the music I like. The first time I saw multiroom
audio was as a 14 year old in a flat with speakers in every room. They were all
connected via flushmounted (unter Putz) cables to the central hifi amp.

Years later, I started to stream audio over WLAN. But as I was using the MPD http output, I had multiroom,
but not synchronous. Hurting my ears whenever changing from the kitchen to the living room.

In 2018, I started with rasperry pi, hifiberry and snapcast. Boooom! True synchronous audio with
individual volume in every room. However, the approach was quite bottom up because all interfaces
were new and I actually had some requirements that forced me to learn even more...
