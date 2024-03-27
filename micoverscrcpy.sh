#!/usr/bin/env sh


# Checks dependencies
for cmd in wpctl scrcpy pw-link pw-loopback; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd not found\!"
        exit 1
    fi
done

# Kills scrcpy on exit
cleanup() {
    echo "Killing..."
    pkill scrcpy
}

# Interrupts interrupts so it can kill scrcpy
trap cleanup SIGTERM
trap cleanup SIGKILL
trap cleanup SIGINT

usage() {
    echo "Usage: $(basename $0) [-c] [-v <volume>]"
    echo "Options:"
    echo "  -c, --camera            Also capture the camera (requires android 12+)"
    echo "  -v, --volume <volume>   Specify the volume of the virtual microphone (default = 1.0)"
    exit 1
}

camera=0
volume=1

# Gets the options, see ```man getopt``` for more
if ! options=$(getopt -o cv: -l camera,volume: -- "$@"); then
    echo ""
    usage
fi

# Parses options
while [ $# -gt 0 ]; do
    case $1 in
        -c|--camera)
            camera=1
            shift ;;
        -v|--volume)
            volume=$2
            shift 2 ;;
        (--)
            shift 2
            break ;;
        (*)
            usage
            break ;;
    esac
done

if [[ $(adb devices | wc -l) -lt 3 ]]; then
    echo "Please connect an adb device (probably your phone)"
    exit 1
fi

if camera;  then
    #TODO: Do fancy things with v4l2 to use the output of this as a webcam feed
    scrcpy --audio-source=mic --video-source=camera &
else
    scrcpy --audio-source=mic --no-video &
fi

sleep 1

#Finds default sink with wpctl
DEFAULTSINK=$(wpctl inspect @DEFAULT_SINK@ | awk 'NR<2 {print $2}' | sed 's/\,//')
# Finds the ID of the scrcpy stream
SCPSID=$(wpctl status | grep "scrcpy" | awk 'NR>1 {print $1}' | sed 's/\.//')
# Unlinks the source from your output device
echo ""
echo "scrcpy id: $SCPSID"
echo "default id: $DEFAULTSINK"

pw-link -d $SCPSID $DEFAULTSINK
#Sets the volume of the microphone
wpctl set-volume $SCPSID $volume

# Starts a task that links the output of scrcpy to a source called "virtmic"
pw-loopback --capture-props='node.target=scrcpy' --playback-props='media.class=Audio/Source node.name=virtmic node.description="VirtualMic"'
