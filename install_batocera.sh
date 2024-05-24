#!/bin/bash

# Variables
MarqueeIP="192.168.7.2"  # IP address of Pi Zero 2 W

# Create necessary directories
mkdir -p /userdata/system/scripts

# Create game-start.sh script
cat << 'EOF' > /userdata/system/scripts/game-start.sh
#!/bin/bash
Marqueeip=192.168.7.2 # IP address of Pi Zero 2 W
case $1 in
    gameStart)
        romname=${5##*/}
        gamename=${romname%.*}
        echo "./marquee.sh GameStart \"$2\" \"$gamename\"" | nc $Marqueeip 5555 >temp.log &
        ;;
    gameStop)
        echo "sudo pkill ffmpeg" | nc $Marqueeip 5555 &
        ;;
esac
EOF

# Create game-selected.sh script
cat << 'EOF' > /userdata/system/scripts/game-selected.sh
#!/bin/bash
Marqueeip=192.168.7.2 # IP address of Pi Zero 2 W
System=$1
Romname=${2%.*}
rom=${Romname##*/}

echo "./marquee.sh Gameselected \"$System\" \"$rom\"" | nc $Marqueeip 5555 >temp.log &
EOF

# Create system-selected.sh script
cat << 'EOF' > /userdata/system/scripts/system-selected.sh
#!/bin/bash
Marqueeip=192.168.7.2 # IP address of Pi Zero 2 W
System=$1

echo "./marquee.sh Systemselected \"$System\"" | nc $Marqueeip 5555 >temp.log &
EOF

# Make scripts executable
chmod +x /userdata/system/scripts/game-start.sh
chmod +x /userdata/system/scripts/game-selected.sh
chmod +x /userdata/system/scripts/system-selected.sh

echo "Batocera setup completed."
