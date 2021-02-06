# multiroom
Step by step tutorial to install and configure a multiroom audio setup.  Based on mpd, snapcast and icecast to support ALSA sources. Play your local music files and internet radio stations synchronously to all rooms. Or from any bluetooth audio source (including your mobile). Or even your vinyl records.

## Design

### Goals

* Use standard software and hardware components as far as possible
* Rely on existing IP-Network (LAN, WLAN, even VPN) and DNS.
* Have only one pair of loudspeakers per room and make them universally usable (i.e. as bluetooth audio sink).
* Integrate the HiFi-Amp as sound sink **and** sound source, so that I can stream my vinyl records synchronously to all rooms.
* Maximise sound quality: No conversion of the audio signal in any way (resampling, lossy codecs, ...)
* Maximise digital sovereignty: No need to integrate streaming services that make it almost impossible to downlad a text version of **my own** playlists (hi spotify). If you really need it: Use the app on your mobile or desktop and connect via bluetooth.

### Limitations (learned the hard way)

* Every (?) soundcard has one global clock for the sampling rate (maybe for the sample size too). This seems to be well known, but ist not well documented: You cannot record at 48000/16/2 from the soundcard while playing something else at 44100/16/2. I spent some hours with unclear error messages, erratic behaviour (sometimes a command worked, sometimes not) until I discovered this basic limitation. 

* Do **not** install mpd/snapserver on a VM. You will have dropouts. If anyone knows how to set priorities (on the KVM host and/or in the VM itself) so that the dropouts stop, I would be very happy to learn it. So install them on dedicated HW (like the Raspberry Pi).

## Overview

### Hardware components

* Raspberry Pi (I use a *Zero W Rev 1.1*, two *3 B+ Rev 1.3* and a *4 B Rev 1.1*)
* HifiBerry with line level in and out:  [dac+ adc](https://www.hifiberry.com/shop/boards/hifiberry-dac-adc/) 
* HifiBerry with integrated amp and loudspeaker connectors: 
  * 60W: [AMP2](https://www.hifiberry.com/shop/boards/hifiberry-amp2/) 
  * 3W: [MiniAmp](https://www.hifiberry.com/shop/boards/miniamp). Louder than you expect!
* Hifi-amplifier with a separate **Rec** selector: In order to stream an analog source (connected to your amp) synchronously to all rooms (including the room with the analog source), you need to be able to send the music e.g. from your turntable to the "REC OUT" connectors while having e.g. the tuner on your loudspeakers.

### Software components

* **alsa**: Plain ALSA for audio input/output. No PulseAudio, no Jack.
* **mpd**: The core of the solution is plain old mpd. All mpd clients continue to work, all music files continue to work.
* **snapcast**: Ensures synchronous playback in all rooms. Kudos go to [badaix](https://github.com/badaix/snapcast). I also installed his [Android App](https://github.com/badaix/snapdroid) on old mobile phones that are now universal remote controls.
* **bluealsa**: A daemon that is able to create a virtual ALSA sound card from an established bluetooth A2DP connection.
* **a2dp-agent**: A Bluetooth Agent that handles a connection request from an bluetooth A2DP audio source. Original Code is [here](https://gist.github.com/mill1000/74c7473ee3b4a5b13f6325e9994ff84c). I use a patched version as I want to have the option to output the bluetooth audio either to the local ALSA card (supported by original code) **or** to an icecast stream (not supported).
* **icecast**, **ffmpeg**: Used to distribute audio from analog/bluetooth sources to mpd. 
* a few glue scripts and adjusted .service files.

### Short comparison to other solutions

* [Super-Simple-Raspberry-Pi-Audio-Receiver-Install](https://github.com/BaReinhard/Super-Simple-Raspberry-Pi-Audio-Receiver-Install): much more automated install, but discontinued. 
* [HydraPlay](https://github.com/mariolukas/HydraPlay): Even more generic than my proposal, but uses mopidity (and has an instance on every device)
* [https://github.com/tomtaylor/multiroom-audio](https://github.com/tomtaylor/multiroom-audio): Just containers around snapserver/snapclient.
* [snapcast-autoconfig](https://github.com/ahayworth/snapcast-autoconfig): A solution that automatically reconfigures snapclients. Groups multiple rooms (snapclients) together to a "stream" and helps to play different music to different rooms. Might be interesting for later inclusion.
* [frafall/multiroom](https://github.com/frafall/multiroom): Full media center and multiroom, Kodi integration etc. Bloated for my use case.
* [Wireless Multi-Room Audio System For Home](https://github.com/skalavala/Multi-Room-Audio-Centralized-Audio-for-Home): Uses mopidy (vs mpd) and PulseAudio (vs ALSA).

So it looks like I have reinvented the wheel - but only partially. None of the solutions above integrate bluetooth **and** analog sources. And I learned a lot!

## Build it

During my journey, I found out that playing around with audio can be tricky. If only one of the many volume controls between source and sink is at zero, you can't hear anything and you don't know whether it actually works. Therefore, the following is a bottom up tutorial, i.e. you start with the simplest configuration, test it (can you hear something?) and continue to the next step only if everything is ok.

### Hardware installation

* Install Raspbian (based on Debian buster). Be sure to set the keyboard mapping correct, as the default password contains a **y**!
* Disable the internal soundcard and enable the correct soundcard in `/boot/config.txt`
* Connect the raspi to the network (LAN or WLAN): Static IP, create a DNS entry in your local DNS server. Choose the hostname wisely, you will use it to connect to your raspi with the mpd controller, the snapcast controller and clients, bluetooth clients etc. The name is transparent to the end users. I called my boxes by the room they are in (like bathroom) or after the loudspeakers they play sound to (like infinity). 
* Connect the audio inputs/outputs and/or the loudspeakers.
* Configure the default audio format for the ALSA `dmix` and `dsnoop` devices in `/etc/asound.conf`. You can decide to use other sampling rates / sample sizes.

  **Warning**: In this tutorial, I always work with the same explicit audio format everywhere, so you will have to adjust almost every command line in this tutorial. I have ripped my 1000+ CDs to FLAC, so most of my audio material is 44100/16/2. 

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
            
* Unfortunately, the output shows both sources and sinks, and some sinks can also be used as sources. I'm just too stupid to understand ALSA.
          
* Now you need a `.wav` file with the correct sampling rate:

        # file the_girl_tried_to_kill_me.wav 
        the_girl_tried_to_kill_me.wav: RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, stereo 44100 Hz

* Play it with `aplay`

        aplay -D dmix:CARD=sndrpihifiberry,DEV=0 the_girl_tried_to_kill_me.wav

* If you can't hear anything, play with the `alsamixer` settings until you hear something. If this does not help, you have another issue that you need to fix. It does make any sense to go further until this works.

### Test ALSA input (if present and desired)

* Open the `alsamixer` again, but switch to the *Capture* Settings using the `F4` key.
* Connect an audio source to the analog input (3.5mm stereo jack on DAC+ADC). This can be a mobile with a headphone jack (pump up the volume on the mobile to 100% !), or the **REC** outputs of your amp. 
* It's time now to check out the input gain jumpers on the DAC+ADC. I left them in the default position (+0dB), but you have the option to add a 12dB or even 32dB gain with the jumpers. Be aware: It's digital audio processing, there is an absolute peak value: if you are amplifying too much, you will have distortion. You should get as near as possible to 100% (maximize signal/noise ratio), but never reach it!
* Find out the correct source with `arecord -L` (output similar - or identical ? - to above)
* You can test whether you receive any sound by using the `arec` VU meter (the last line on stdout should show some movement) 

        arecord -f cd -D dsnoop:CARD=sndrpihifiberry,DEV=0 -vv -V stereo /dev/null

* You can also loop the input directly to the output (which is confirmed to work due to the previous step): 

        arecord -f cd -D dsnoop:CARD=sndrpihifiberry,DEV=0 | aplay -D dmix:CARD=sndrpihifiberry,DEV=0

* You should hear now on your loudspeakers what you are feeding to the analog input. This is the moment to optimize all mixer settings (being it ALSA or on your sound setup). In general, all volume controls should be at 100% except the very last one controlling the final sink. This ensures maximum signal/noise ratio.

### Snapcast

The snapcast server needs to run on the same machine as mpd, as the music is sent to snapcast using a named pipe in `/tmp/`. In my case this is the **infinity** raspi. As I want to use the alsa output too, I need both client and server on this raspi. On all others, you just need the client (Hint: The packaging for debian and for raspbian differs in the naming of the user, I describe the raspbian way here).

    apt-get install snapserver snapclient 
    
`/etc/default/snapserver`

    SNAPSERVER_OPTS="-s pipe:///tmp/snapfifo?name=mpd&sampleformat=44100:16:2&codec=flac --buffer=40"
    
If you have dropouts, increase the buffer value (which causes the the latency from audio input to output to increase)

#### snapclient 

The default output device for snapclient is the alsa default device, which happens (unfortunately) to be the `hw` device. As said before, you should use `dmix` whenever possible. Therefore we need first to find out by what number the `dmix` is known to snapclient:

    snapclient -l 
    
    ...
    3: dmix:CARD=sndrpihifiberry,DEV=0
    snd_rpi_hifiberry_dacplusadc, HiFiBerry DAC+ADC HiFi multicodec-0
    Direct sample mixing device
    ...
    
The config file `/etc/default/snapclient` is therefore

    START_SNAPCLIENT=true
    SNAPCLIENT_OPTS="--user _snapclient:audio -h snap.iselin.net -s 3 --hostID infinityID"

The hostID is helpful to identify all snapclients properly.

#### Test snap

If you have `mpd` already running, stop it.

    systemctl stop mpd
    systemctl start snapserver
    systemctl start snapclient
    
Verify that both snapserver and snapclient are running (e.g. with `ps -ef | grep snap | grep -v grep`) 

If you still don't have a `/tmp/snapfifo` yet, create it so that it looks like this

    prw-rw-rw- 1 _snapserver _snapserver 0 Feb  3 23:17 /tmp/snapfifo

Now try to feed the same `.wav` file as above to the snapserver input:
    
    sox the_girl_tried_to_kill_me.wav -t raw - > /tmp/snapfifo

You should now hear the song on your loudspeakers as above (with some delay added). 

### mpd

    apt-get install mpd
    
Add to the config the following block (you might want to change a lot of other things, but this is key to send the mpd output to the snapserver:

    audio_output { 
        type            "fifo"
        name            "my pipe"
        path            "/tmp/snapfifo"
        format          "44100:16:2"
        mixer_type      "software"
    }
    
According to [christf](https://github.com/christf/snapcastc), it might be preferrable to use the mpd `pipe` output instead of the `fifo` output. I did not test it, `fifo` works for me without issues.

#### Test mpd

The easiest way to test mpd is to connect to it with a client (I use `mpc` on the command line/in scripts, `sonata` in Gnome) and feed an internet radio station to it. To connect to mpd, you need to know the hostname (**infinity** in my case) and the port (default **6600**).

In order to enqueue a radio station and play it, use (on the raspi with `mpd`)

     mpc -h localhost add http://stream-uk1.radioparadise.com/aac-320
     mpc -h localhost play 
     
If you can hear sound now, you have verified that the communication from **mpd** to **snapserver** to **snapclient** to **alsa** works :-) If not, you need to debug!

#### Customize mpd: Add alsa input config (with DAC+ADC)

As I discovered only very late during my experiments, mpd can actually read from an alsa source directly. We configure the source in the config file:

    input { 
            plugin "alsa"
            default_format "44100:16:2"
            auto_resample "no"
            auto_channels "no"
            auto_format "no"
    }
    
If you connect again something to the raspi input connector and have verified with `arecord` that the soundcard actually receives audible sound, then enque the following to the mpd playlist

      mpc -h localhost add alsa://dsnoop:CARD=sndrpihifiberry,DEV=0
      
When you play this "song", `mpd` will put the sound from the alsa input into the snapfifo and you can hear (in all rooms) what is currently fed to the local ALSA source). This shortcut works only on the raspi where mpd is running, to feed analog (or bluetooth) audio from remote raspis, we need to introduce another technology. Read on. 

#### Customize mpd: Add music collection

If you have a music collection on your **NAS** it is time to mount the music collection from there onto `/var/lib/mpd/music` and have mpd index the files:

     mpc -h localhost update
     
Depending on the size of your collection, the network and NAS speed, this can take a while. Watch `tail -f /var/log/mpd/mpd.log` for completion.

### Icecast

Icecast has been designed to create an internet radio station. We will use icecast on every raspi that needs to feed at least one input (analog or bluetooth) over the network to the central mpd. Other solutions solve this problem by installing mpd on every raspi (i.e. there is not one "central" mpd). This is a very symmetric and therefore beautiful solution, but I am not sure if this setup would work for bluetooth sources too. 

In order to stream music over icecast, you need an icecast server and one or more so called *ices*. Every *ice* can create an independent stream in the icecast server.

    apt-get install icecast
    
The config file is `/etc/icecast2/icecast.xml`. The *ices* need to authenticate against the icecast server with the user `source`, so you need to adjust its password (please choose your own with `pwgen 12 1`:

    <source-password>Hiesh0vahHoh</source-password>
    
Not needed for the moment, but I suggest to set the relay- and admin- Passwords too. If - and only if -  you are the only person that connects to the icecast Server, you can set them all to the same value. 

Check the following setting, we will use it in the next section.

    <listen-socket>
        <port>8000</port>
    </listen-socket>
    
#### ices: ffmpeg (with local test file) 

There are many programs that can be used as *ice*, I started first with `ices2` which is configured via xml files similar to the icecast server. I discovered  `ffmpeg` later and am working now with this only - it is much simpler for me to see all relevant parameters on the command line than set options dispersed in an xml file. In order to play an audio file to the icecast server, use

    ffmpeg -re -loglevel warning \
           -i the_girl_tried_to_kill_me.wav  \
           -f ogg -c:a flac \
           -ar 44100 -ac 2 \
           -ice_name "Ice Name" -ice_url http://infinity:8000/onewav.ogg \
           -ice_description "WAV to icecast (flac) via ffmpeg" -content_type 'application/ogg' \
           icecast://source:Hiesh0vahHoh@localhost:8000/onewav.ogg

This command will create a new icecast stream for the duration of the song. So don't wait, fire up your browser and connect to 

    http://infinity:8000/
    
You should see the icecast server page and the stream created above. You must be able to listen to the stream in the browser: Either click the *play* button or enter the stream URL directly:

    http://infinity:8000/onewav.ogg
    
If you can hear the sound via browser, your icecast setup works. 

### Analog input to icecast

Even if you don't do/need this, please read this short section. It helps to understand what we will do with bluetooth later.

The only thing we need is a process that feeds the analog input to the icecast server and creates a stream. This is the same oneliner as above, we just read the sound from alsa and not from a `.wav` file.


    ffmpeg -nostats -loglevel warning \
           -f alsa -ar 44100 -ac 2 -i dsnoop:CARD=sndrpihifiberry,DEV=0  \
           -f ogg -c:a flac \
           -ice_name "Analog Infinity FLAC" -ice_url http://infinity:8000/alsa.ogg \
           -ice_description "ALSA to icecast (flac) via ffmpeg" -content_type 'application/ogg' \
           icecast://source:Hiesh0vahHoh@localhost:8000/alsa.ogg
           
Now feed some audio signal to the input port of the HifiBerry-Board (see above) and use the browser on your workstation to listen to stream (provided that you still have some loudspeakers connected):

    http://infinity:8000/alsa.ogg
    
Even better, you can feed it as "song" on the playlist to `mpd`:

    mpc -h localhost add http://infinity:8000/alsa.ogg
    
This adds some delay, but should basically sound identical to the solution above where we enqueued the "song" that points directly to the ALSA `dsnoop` device. However, when using `dsnoop`, the analog audio source must be on the same physical box as `mpd`. With icecast, you can read the analog input on one device and feed it over the network to `mpd` running on a different device.

Now you are ready  to stream your vinyl records to all rooms!

### Bluetooth input (to alsa or icecast)

Ready for the boss fight? So let's go:

The goal is to convert the raspi into something that looks like a bluetooth audio sink (i.e. bluetooth loudspeakers). However, there are some limitations that make the implementation much trickier than the *analog input* above:

* You cannot attach a program to a non-existing alsa device and just wait until it exists. If you try it, the program will exit immediately with `arecord: main:828: audio open error: No such file or directory`
* A bluetooth device is identified by its (hopefully unique) bluetooth MAC address. 
* While bluetoothd can handle everything to actually move data from/to bluetooth, you need a so called bluetooth agent to perform the necessary steps to automatically "pair" a bluetooth device.
* There are many different usages of bluetooth, for audio we use the bluetooth A2DP profile.
* The bluetooth standard requires the device manufacturers to implement A2DP with a 48000 sampling rate, the support of 44100 is optional. I decided to force 44100 and hope that all my bluetooth clients will be compatible. No issues so far.

#### Configure bluetoothd 

Warning: this is **not safe**, but it's very handy: We will configure bluetoothd to make the device discoverable forever so that you can pair whenever you want. As we don't want to do any authentication, it is possible that a neighbour of you connects to your bluetooth device and you suddenly hear his music, his phone call, whatever. Now that you've read and understood the warning, we change `/etc/bluetooth/main.conf` as follows:

    DiscoverableTimeout = 0
    
#### bluealsa
 
    apt-get install bluealsa
    
As we want to use bluealsa for audio input only and force the sample rate to 44100, we change the `bluealsa.service` file as follows:
  
    dpkg-divert --divert /lib/systemd/system/bluealsa.service-DIVERTED --local --rename --add /lib/systemd/system/bluealsa.service
    cd /lib/systemd/system
    cp -p bluealsa.service-DIVERTED bluealsa.service
    
Change the ExecStart line

    ExecStart=/usr/bin/bluealsa --profile=a2dp-sink --a2dp-force-audio-cd
    
And restart bluealsa

    systemctl restart bluealsa

As soon as bluealsa is properly running, you should see that the bluetooth controller has a new function:

    bluetoothctl show

There is a new line saying.

    UUID: Audio Sink                (0000110b-0000-1000-8000-00805f9b34fb)

You can verify this by stopping bluealsa and checking again. In addition, you can verify that bluealsa is properly running with alsamixer:

    alsamixer -V capture -D bluealsa

You will see a warning that there are no controls. That's ok, they will appear later when we have connected a bluetooth device. But when alsamixer complains about not finding the device at all, there is something wrong with bluealsa.

#### Manual bluetooth pairing

In order to connect your mobile to the raspi over bluetooth, you need `bluetoothctl`:

On your mobile, start playing any audio (I discovered that when you don't play any music, the bluetooth-connection dies. Unclear whether this is a (power saving ) feature of the mobile or a bug somewhere. Don't panic, this is only an issue when you manually try to pair the device.).

On your mobile, search for bluetooth devices, you should see `ìnfinity` (or whatever hostname you chose). The raspi should appear like any bluetooth loudspeaker (sometimes as a headset).

On the raspi, start `bluetoothctl` (a bluetooth agent)

    [bluetooth]# list
      Controller DC:A6:32:34:6E:91 infinity [default]
    [bluetooth]# scan on
      ...
      [NEW] Device 20:39:56:AF:C1:8B Nokia7
      ...
    [bluetooth]# pair 20:39:56:AF:C1:8B

As far as I found out, you don't need to `trust` the device. 

    [bluetooth]# info 20:39:56:AF:C1:8B
       ...
       Paired: yes
       Trusted: no
       Connected: yes

The mobile is still appears to play music, but you can't hear anything anymore because the sound goes to bluetooth (and not the mobile's speakers any more). 

#### Manually play bluetooth audio to the raspi

Now that your mobile (audio source) is connected to the RaspberryPi (A2DP audio sink), this should work

    MAC="20:39:56:AF:C1:8B" 
    arecord -f cd -D bluealsa:SRV=org.bluealsa,DEV=$MAC,PROFILE=a2dp --dump-hw-params | aplay -f cd -D dmix:CARD=sndrpihifiberry,DEV=0 --dump-hw-params    

If `arecord` complains about `no such device`, the pairing did not work or is already terminated for some reason. Or `bluealsa` is stopped. Otherwise, you can now hear the sound from the loudspeakers connected to the raspi. So this basically converts your raspi into a bluetooth audio converter.

**Note**: As we are outputting to the `dmix` and not the `hw` device, it's possible to still have e.ge. the snapclient playing audio and **at the same time** the pipeline above plays the bluetooth sound.

#### Manual creation of icecast stream

Now that your mobile (audio source) is connected to the RaspberryPi (A2DP audio sink), the following commandline would be sufficient to create the icecast stream from the mobile:

    MAC="bluetooth mac address of connected A2DP source" 
    arecord -f cd -D bluealsa:SRV=org.bluealsa,DEV=$MAC,PROFILE=a2dp --dump-hw-params | ffmpeg -nostats -loglevel warning \
            -f s16le \
            -ar 44100 -ac 2 \
            -i - \
            -f ogg -c:a flac \
            -ice_name "Infinity Blue FLAC" -ice_url http://infinity:8000/blue.ogg \
            -ice_description "Bluealsa to icecast (flac) via ffmpeg" -content_type 'application/ogg' \
            icecast://source:Hiesh0vahHoh@localhost:8000/blue.ogg
            
As before, fire up your browser, go to `http://infinity:8000/blue.ogg`  and you should hear the mobile's sound on the loudspeakers of your desktop. If not, check that the bluetooth volume of your mobile is at 100% (again).

#### Automate all this 

Now we have all low level building blocks together and need to glue them together

* **Analog input to icecast**
  *  `/etc/systemd/system/ffmpeg.service`
  *  `/usr/local/bin/alsa-to-icecast`: a simple loop around the `ffmpeg` command described above
* **Bluetoooth input to alsa or to icecast
  Sometimes you want to use the raspi just as a local bluetooth loudspeaker (no multiroom, but lower latency). Typical use case would be watching a video. Sometimes you really want to stream bluetooth to all rooms (at the price of higher latency). Currently, I have implemented both and use a config file to define what should happen after a bluetooth connection. It would be nice if there to have a hardware button and an LED on the raspi that would allow you to select the "bluetooth output mode". 
  * `/usr/local/bin/a2dp-agent`: Patched Version that starts a shell script upon connection
  * `/usr/local/bin/a2dp-to-ice`: Shell script called from `a2dp-agent` to fire up the needed process pipelines to send the A2DP audio to alsa or bluetooth
  
## Latency

Every additional handover of the audio stream from a process to the next introduces some additional latency (i.e. the time it takes from an audio signal entering the system until it gets output by the loudspeakers). You may have noticed one or the other `buffer` setting. Every audio processing process needs to process some samples at once. The bigger the buffer, the bigger the latency - but the smaller the chance of dropouts. So buffers should be just big enough to prevent dropouts. The exact value is probably dependent on your environment. The following picture shows various configurations implemented above, grouped by latency.

The horizontal lines at the top and the bottom mark the boundary between the ALSA driver (outside) and the audio processing userspace programs (inside). Audio data flows from top ("source") to bottom ("sink").

When a process has more than one input (`mpd`), there is an easy way to select one of them.

When a process has more than one output, multiple outputs can be driven at once. In the special case of `snapserver`, you even have the promise of the audio being played synchronously on all clients.

![](ALSArec2ALSAplay.png)

The vertical size is **not** in relation to the latency added. The processes are aligned horizontally so that the same interface is at the same level.
    
## ToDo 

* add a chapter about latency and add a few pictures to visualize what is going on / where the audio stream flows ...
* rename some of the scripts a s the name does not properly reflect their respective functions.
* properly fork a2dp-agent
* properly put the glue scripts here in github
  
## Wishlist

* It is possible to bypass `mpd` in certain use cases while still maintaining multiroom capabilities: The audio is played directly to the snapserver fifo. As the fifo should (can ?) only be written to by one process, you would need to stop `mpd` before e.g. starting `arecord ... > /tmp/snapfifo` and start it again when needed. This will need one or more additional glue scripts to switch mode **and** a way to call them remotely (ssh/web/...). As long as `mpd` is running, you can choose from many different remote `mpd` control clients - for many plattforms. 

* Better audio quality on analog input: Tests comparing "loopback" with Cinch-Cable to "loopback" via arecord/aplay showed that higher sampling rates on input actually make an audible difference. Even for my old ears. However, this conflicts with the requirement that we need to have the same sampling rate on input and output and want to limit audio conversions to a minimum. 

* Easy Switch Bluetooth-Input config between local alsa out (lower latency, but no multiroom, suitable e.g. for watching TV) and icecast out (high latency, but multiroom, suitable for listening to music only).

* Easy enable/disable pairing so that you don't have to fear your neighbours bluetooth clients any more.

* Technical: The current implementation in `a2dp-agent` has a flaw that has not functional impact, but is *not nice*: After `a2dp-agent` has connected a bluetooth device and has called `a2dp-to-ice`, the latter runs as daughter process of the former - as long as the bluetooth connection is established. After termination of the bluetooth connection, the `arecord` process fails (because the alsa device vanished) and `a2dp-to-ice` terminates. So far so good. But now the patched `a2dp-agent` does not immediately *reap* the terminated subprocess, so you will see in `ps` a zombie `a2dp-to-ice` process. The *reaping* happens when a new bluetooth connection is established only.
