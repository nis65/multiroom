# multiroom
Multiroom audio setup based on mpd and snapcast, supporting analog and bluetooth sources. No automated installation (yet).

## Design

### Goals

* Use standard software and hardware components as far as possible
* Rely on existing IP-Network (LAN, WLAN, even VPN) and DNS.
* Have only one pair of loudspeakers per room and make them universally usable (i.e. as bluetooth audio sink).
* Integrate the HiFi-Amp as sound sink **and** sound source, so that I can stream my vinyl records synchronously to all rooms.
* Maximise sound quality: No conversion of the audio signal in any way (resampling, lossy codecs, ...)
* Maximise digital sovereignty: No need to integrate streaming services that make it almost impossible to downlad a text version of **my own** playlists (hi spotify). If you really need it: Use the app on your mobile or desktop and connect via bluetooth.

### Limitations

* Every soundcard seems to have one global clock for the sampling rate (maybe for the sample size too). This seems to be well known, but documented poorly. You cannot record audio at 48000/16/2 from the soundcard while playing audio at 44100/16/2. I spent some hours with unclear error messages, erratic behaviour (sometimes a command worked, sometimes not) until I discovered this basic limitation. 

* Do **not** install mpd/snapserver on a VM. Install it on dedicated HW (like the Raspi). You will have dropouts. If anyone knows how to set priorities (on the KVM host and/or in the VM itself) so that the dropouts stop, I would be very happy to learn it.

## Overview

### Hardware components

* Raspberry Pi (I use a *Zero W Rev 1.1*, two *3 B+ Rev 1.3* and a *4 B Rev 1.1*)
* HifiBerry with line level in and out:  [dac+ adc](https://www.hifiberry.com/shop/boards/hifiberry-dac-adc/) 
* HifiBerry with loudspeaker connectors (no amp needed any more): 
  * 60 W: [AMP2](https://www.hifiberry.com/shop/boards/hifiberry-amp2/) 
  * 3W: [MiniAmp](https://www.hifiberry.com/shop/boards/miniamp). Louder than you think!
* Hifi-amplifier with a separate **Rec** selector: In order to stream an analog source (connected to your amp) synchronously to all rooms (including the room with the analog source), you need to be able to send the music e.g. from your turntable to the "REC OUT" connectors while having e.g. the tuner on your loudspeakers.

### Software components

* **alsa**: Plain ALSA for audio input/output. No PulseAudio, no Jack.
* **mpd**: The core of the solution is plain old mpd. All mpd clients continue to work, all music files continue to work.
* **snapcast**: To ensure synchronous playback in all rooms. Kudos go to [badaix](https://github.com/badaix/snapcast). I also installed his [Android App](https://github.com/badaix/snapdroid) on old mobile phones that are now universal remote controls.
* **a2dp-agent**: A Bluetooth Agent that handles a connection request from an bluetooth A2DP audio source. Original Code is [here](https://gist.github.com/mill1000/74c7473ee3b4a5b13f6325e9994ff84c). I use a patched version as I want to have the option to output the bluetooth audio either to the local ALSA card (supported by original code) **or** to an icecast stream (not supported out of the box). Details below.
* a few glue scripts and adjusted .service files. Details below.

### Short comparison to other solutions

* [Super-Simple-Raspberry-Pi-Audio-Receiver-Install](https://github.com/BaReinhard/Super-Simple-Raspberry-Pi-Audio-Receiver-Install): much more automated install, but discontinued. 
* [HydraPlay](https://github.com/mariolukas/HydraPlay): Even more generic than my proposal, but uses mopidity (and has an instance on every device)
* [https://github.com/tomtaylor/multiroom-audio](https://github.com/tomtaylor/multiroom-audio): Just containers around snapserver/snapclient.
* [snapcast-autoconfig](https://github.com/ahayworth/snapcast-autoconfig): A solution that automatically reconfigures snapclients. Groups multiple rooms (snapclients) together to a "stream" and helps to play different music to different rooms. Might be interesting for later inclusion.
* [frafall/multiroom](https://github.com/frafall/multiroom): Full media center and multiroom, Kodi integration etc. Bloated for my use case.
* [Wireless Multi-Room Audio System For Home](https://github.com/skalavala/Multi-Room-Audio-Centralized-Audio-for-Home): Uses mopidy (vs mpd) and PulseAudio (vs ALSA).

So it looks like I have reinvented the wheel. But as far as I can tell, none of the solutions above integrate bluetooth **and** analog sources.

## Build it

During my journey, I found out that playing around with audio can be tricky. If only one of the many volume controls between source and sink is at zero, you can't hear anything and you don't know whether it actually works. Therefore, the following is a bottom up tutorial, i.e. you start with the simplest configuration, test it (can you hear something?) and continue to the next step only if everything is ok.

### Hardware installation

* Install Raspbian (based on Debian buster). Be sure to set the keyboard mapping correct, as the default password contains a **y**!
* Disable the internal soundcard and enable the correct soundcard in `/boot/config.txt`
* Connect the raspi to the network: Static IP, create a DNS entry in your local DNS server. LAN or WLAN
* Connect the audio inputs/outputs and/or the loudspeakers.
* Configure the default audio format for the ALSA `dmix` and `dsnoop` devices in `/etc/asound.conf`. You can decide to use other sampling rates / sample sizes. I have ripped my 1000+ CDs to FLAC, so most of my audio material is 44100/16/2 anyway. Your mileage may vary.
arecord -D dsnoop:CARD=sndrpihifiberry,DEV=0 -vv -V stereo /dev/null | aplay -D dmix:CARD=sndrpihifiberry,DEV=0

        defaults.pcm.dmix.rate 44100
        defaults.pcm.dmix.format S16_LE
        defaults.pcm.dsnoop.rate 44100
        defaults.pcm.dnsoop.format S16_LE

### Test ALSA output

* Start `alsamixer` in a terminal window.
* `aplay -L` in another terminal window. The output might be something like

        null
            Discard all samples (playback) or generate zero samples (capture)
        default:CARD=sndrpihifiberry
            snd_rpi_hifiberry_dacplusadc, 
            Default Audio Device
        sysdefault:CARD=sndrpihifiberry
            snd_rpi_hifiberry_dacplusadc, 
            Default Audio Device
        dmix:CARD=sndrpihifiberry,DEV=0
            snd_rpi_hifiberry_dacplusadc, 
            Direct sample mixing device
        dsnoop:CARD=sndrpihifiberry,DEV=0
            snd_rpi_hifiberry_dacplusadc, 
            Direct sample snooping device
        hw:CARD=sndrpihifiberry,DEV=0
            snd_rpi_hifiberry_dacplusadc, 
            Direct hardware device without any conversions
        plughw:CARD=sndrpihifiberry,DEV=0
            snd_rpi_hifiberry_dacplusadc, 
            Hardware device with all software conversions
            
* Unfortunately, the output shows both sources and sinks, and some sinks can also be used as sources. I'm too stupid to understand ALSA.
          
* Now you need a `.wav` file with the correct sampling rate:arecord -f cd -D dsnoop:CARD=sndrpihifiberry,DEV=0 -vv -V stereo /dev/null

        # file the_girl_tried_to_kill_me.wav 
        the_girl_tried_to_kill_me.wav: RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, stereo 44100 Hz

* Play it with `aplay`

        aplay -D dmix:CARD=sndrpihifiberry,DEV=0 the_girl_tried_to_kill_me.wav

* If you can't hear anything, play with the `alsamixer` settings until you hear something. If this does not help, you have another issue that you need to fix. It does make any sense to go further until this works.

### Test ALSA input (if present and desired)

* Open the `alsamixer` again, but switch to the *Capture* Settings using the `F4` key.
* Connect an audio source to the analog input (3.5mm stereo jack on DAC+ADC). This can be a mobile with a headphone jack (pump up the volume to 100% !), or the **REC** outputs of your amp. 
* This test is the right moment to check out the input gain jumpers on the DAC+ADC. I left them in the default position (+0dB), but you have the option to add a 12dB or even 32dB gain with the jumpers. Be aware: It's digital audio processing, there is an absolute maximum peak value: if you are amplifying too much, you will have distortion. You should get as near as possible to 100% (maximize signal/noise ratio), but never reach it!
* Find out the correct source with `arecord -L` (output similar - or identical ? - to above)
* You can test whether you receive any sound by using the `arec` VU meter: 

        arecord -f cd -D dsnoop:CARD=sndrpihifiberry,DEV=0 -vv -V stereo /dev/null

* You can also loop the input directly to the output (which is confirmed to work due to the previous step): 

        arecord -f cd -D dsnoop:CARD=sndrpihifiberry,DEV=0 | aplay -D dmix:CARD=sndrpihifiberry,DEV=0

* You should hear now on your loudspeakers what you are feeding to the analog input. This is the moment to optimize all mixer settings (being it ALSA or on your sound setup). In general, all volume controls should be at 100% except the very last one controlling the final sink. This ensures maximum signal/noise ratio.

### Snapcast
### mpd
### Analog input (to icecast)
### Bluetooth input (to local alsa OR icecast)
## Wishlist

