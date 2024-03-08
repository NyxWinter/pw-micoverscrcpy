#!/usr/bin/env sh


# Checks dependencies
for cmd in wpctl scrcpy pw-link pw-loopback; do
    if ! command -v $cmd &? /dev/null; then
        echo "Error: $cmd not found\!"
        exit 1
    fi
done

# Kills scrcpy on exit
cleanup() {
    echo "Killing..."
    pkill .scrcpy-wrapped
}

# Interrupts interrupts so it can kill scrcpy
trap cleanup SIGTERM
trap cleanup SIGKILL
trap cleanup SIGINT

if [[ $1 ]]; then
    if [[ $1 == "--camera" ]]; then
        scrcpy --audio-source=mic --video-source=camera &
    else
        # TODO: Do a fancy thing with v4l2 to use the output of this as a webcam feed
        echo "To use the camera as a video output (sort of) use --camera, else just run the script"
    fi
else
    scrcpy --audio-source=mic --no-video &
fi

sleep 1

#Finds default sink with wpctl
DEFAULTSINK=$(wpctl inspect @DEFAULT_SINK@ | awk 'NR<2 {print $2}' | sed 's/\,//')
# Finds the ID of the scrcpy stream
SCPSID=$(wpctl status | grep ".scrcpy-wrapped" | awk 'NR>1 {print $1}' | sed 's/\.//')
# Unlinks the source from your output device
echo "scrcpy id: $SCPSID\n default: $DEFAULTSINK\n"
pw-link -d $SCPSID $DEFAULTSINK

# Starts a task that links the output of scrcpy to a source called "virtmic"
pw-loopback --capture-props='node.target=.scrcpy-wrapped' --playback-props='media.class=Audio/Source node.name=virtmic node.description="VirtualMic"'
