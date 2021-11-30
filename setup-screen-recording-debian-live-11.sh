#!/bin/bash

# setup-screen-recording-debian-live-9.sh
#
# Copyright 2017 Matthew T. Pandina. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY MATTHEW T. PANDINA "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL MATTHEW T. PANDINA OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
############################################################################
#
# This script is intended to be run after booting a Debian Live ISO/hybrid
# image. It will download, install, and configure software to make screen
# recordings, with or without audio. When executed, it will present a dialog
# allowing you to select an ALSA audio source to be encoded along with the
# screen capture. If you are using a USB microphone (standalone, or from a
# webcam) plug it in before running this script. If you wish to change the
# audio source, just re-run this script. If you don't wish to record any
# audio, select <Cancel> from the audio selection dialog.
#
# Once you execute this script, you will be able to start recording your
# screen by pressing the Scroll Lock key on your keyboard, and the Scroll
# Lock LED on your keyboard will light up indicating you are "on air"
# (recording). Pressing the Pause key on your keyboard will cause the
# recording to stop, and the Scroll Lock LED will turn off.
#
# The videos are timestamped, so you can start and stop recording as many
# times as you wish without overwriting previously recorded videos.
#
# The full screen is captured, and this script does not need to be re-run if
# you change your screen resolution (but you probably don't want to change
# your screen resolution during the recording!)
#
# For editing your videos after, I recommend downloading the cross distro
# AppImage package of kdenlive: https://kdenlive.org/download/
# I also highly recommend this kdenlive video tutorial series:
# https://www.youtube.com/playlist?list=PLcUid3OP_4OV25ahfqIJcjhpKcT64LQNu
#
# Instructions: Download this script, open a terminal window and type the
#               following commands:
#
#               cd ~/Downloads
#               chmod a+x setup-screen-recording-debian-live-9.sh
#               ./setup-screen-recording-debian-live-9.sh
#
############################################################################

# Ensure the user didn't run this script as root (or using sudo)
if [ "$(id -u)" == "0" ]
then
    echo "This script must run as the desktop user, not as root."
    exit 1
fi

script_dir=$HOME/bin
start_script=${script_dir}/start-screen-recording
stop_script=${script_dir}/stop-screen-recording
script_completed=${script_dir}/.script_completed

# Certain actions are only performed the first time script is run
if [ ! -e ${script_completed} ]
then
    sudo apt-get update
    sudo apt-get install -y dialog ffmpeg screen vlc
fi

# Create the scripts directory
mkdir -p ${script_dir}

# Write out the stop script, and make it executable
cat <<'EOF' > ${stop_script}
#!/bin/bash
pkill --signal SIGINT ffmpeg
EOF
chmod a+x ${stop_script}

# Build a menu array out of the list of ALSA audio sources
menu=""
count=0

for item in $(arecord -L | grep "CARD")
do
    count=$((count+1))
    menu+=("$count" "$item")
done

# Display the configuration dialog
choice=$(dialog \
	     --clear --backtitle "Configure Screen Recording" \
	     --title "Audio Source" \
	     --menu "Select an audio source, or choose <Cancel> to not record audio" \
	     15 76 10 \
	     ${menu[@]} \
	     2>&1 >/dev/tty)

# If choice is empty, we won't record audio
if [ -z "$choice" ]
then
    echo "Audio will not be recorded"
    echo ""
else
    # Extract the ALSA audio source name from the menu array
    source=${menu[$(($choice * 2))]}

    echo "Using: $source"
    echo "       for audio recording."
    echo ""
fi

# Begin creating start_script
cat <<'EOF' > ${start_script}
#!/bin/bash
xset led named 'Scroll Lock'
ffmpeg -y -thread_queue_size 512 \
EOF

# If recording audio
if [ -n "$choice" ]
then
    cat <<EOF >> ${start_script}
-f alsa -i $source \\
EOF
fi

# The screen resolution might change, so don't run xrandr now
cat <<'EOF' >> ${start_script}
-video_size $(xrandr | grep '*' | tr -s ' ' | cut -d ' ' -f 2) \
-r 60 \
-f x11grab \
-i :0.0 \
EOF

# If recording audio
if [ -n "$choice" ]
then
    cat <<'EOF' >> ${start_script}
-acodec libmp3lame -b:a 256k \
EOF
fi

# The video(s) are timestamped, so don't run date now
cat <<'EOF' >> ${start_script}
-vcodec libx264 -preset ultrafast -crf 0 \
$HOME/Videos/output-$(date +%F_%H_%M_%S).mp4
xset -led named 'Scroll Lock'
EOF

chmod a+x ${start_script}

# Setup the custom keyboard shortcuts (Scroll Lock to start, and Pause to end)
# http://askubuntu.com/questions/597395/how-to-set-custom-keyboard-shortcuts-from-terminal

if [ ! -e ${script_completed} ]
then
    # This is meant to run on the Debian 9 Live ISO/hybrid image, where no custom shortcuts
    # exist, so it doesn't bother to preserve any that have been previously defined
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Start Screen Recording'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "${start_script}"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding 'Scroll_Lock'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'Stop Screen Recording'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command "${stop_script}"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding 'Pause'

    # Totem sucks, so reassign all of its file associations to VLC
    # http://askubuntu.com/questions/226745/how-to-set-default-applications-non-interactively-e-g-vlc-as-default-for-video
    printf "Reassigning Totem's file associations to VLC"
    mimetypes=""
    for totem_desktop in $(find /usr/share/applications | grep -i 'totem\.desktop')
    do
	mimetypes+=$(cat "$totem_desktop" | grep "MimeType" | cut -d '=' -f 2 | tr ";" " ")
	mimetypes+=" "
    done
    for mimetype in $mimetypes
    do
	gvfs-mime --set $mimetype vlc.desktop >/dev/null 2>&1
	printf "."
    done
    echo ""

    # I'm sorry, this is the only way I know how to get GNOME to recognize that we added keyboard shortcuts:
    screen -d -m gnome-shell --replace
    # If anyone finds a better way, please let me know!

    # Disable display power savings, since the gnome-shell trick above causes you to be locked out of GNOME if you let the screen go idle for more than 5 minutes
    gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
    gsettings set org.gnome.desktop.session idle-delay 0
fi

echo "Your Debian Live system is now set up for full screen recording."
echo "You may re-run this script at any time to change the audio source."
echo "You do not need to re-run this script if you change your display resolution."
echo ""
echo "Time-stamped screen recordings will be stored in $HOME/Videos/"
echo ""
echo "Use the <Scroll Lock> key to begin recording, and the <Pause> key to stop."
echo ""

# Remove the script_completed file if you ever wish to re-run all parts of the above script
touch ${script_completed}
