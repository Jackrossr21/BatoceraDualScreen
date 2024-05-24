#!/bin/bash

# Variables
OS_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf_latest"
IMAGE_NAME="custom_raspberry_pi_os.img"
GITHUB_REPO="https://github.com/Jackrossr21/BatoceraDualScreen.git"
MOUNT_POINT="/mnt/sdcard"

# Check if the required utilities are installed
if ! command -v wget &> /dev/null || ! command -v git &> /dev/null || ! command -v dd &> /dev/null; then
    echo "Required utilities are not installed. Please install wget, git, and dd."
    exit 1
fi

# Extract Wi-Fi details from Batocera system
WIFI_SSID=$(grep 'ssid=' /etc/network/interfaces | awk -F '"' '{print $2}')
WIFI_PSK=$(grep 'wpa-psk' /etc/network/interfaces | awk '{print $2}')

# List attached external storage devices
echo "Listing attached external storage devices..."
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part"

# Select the SD card or external storage device
read -p "Enter the device name to format (e.g., sdb): " DEVICE
SD_CARD="/dev/$DEVICE"

# Confirm the selection
echo "You have selected $SD_CARD. All data on this device will be erased!"
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
if [[ $CONFIRM != "yes" ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Download the base Raspberry Pi OS image
echo "Downloading the base Raspberry Pi OS image..."
wget -O $IMAGE_NAME $OS_IMAGE_URL

# Unzip the image if necessary
if [[ $IMAGE_NAME == *.zip ]]; then
    echo "Unzipping the downloaded image..."
    unzip $IMAGE_NAME
    IMAGE_NAME="${IMAGE_NAME%.zip}.img"
fi

# Flash the OS image to the SD card
echo "Flashing the OS image to the SD card..."
dd if=$IMAGE_NAME of=$SD_CARD bs=4M status=progress conv=fsync

# Mount the boot partition of the SD card
echo "Mounting the SD card boot partition..."
BOOT_PARTITION="${SD_CARD}1"
mkdir -p $MOUNT_POINT
mount $BOOT_PARTITION $MOUNT_POINT

# Enable SSH
echo "Enabling SSH..."
touch $MOUNT_POINT/ssh

# Configure USB Ethernet Gadget
echo "Configuring USB Ethernet Gadget..."
echo "dtoverlay=dwc2" >> $MOUNT_POINT/config.txt
sed -i 's/$/ modules-load=dwc2,g_ether/' $MOUNT_POINT/cmdline.txt

# Create the first run script
echo "Creating the first run script..."
cat <<EOF > $MOUNT_POINT/firstrun.sh
#!/bin/bash
# Set up auto-login
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOL >/etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOL

# Configure static IP for usb0
cat <<EOL >> /etc/dhcpcd.conf
interface usb0
static ip_address=192.168.7.2/24
static routers=192.168.7.1
static domain_name_servers=192.168.7.1
EOL

# Create necessary directories
mkdir -p /home/pi/Marquee

# Clone the GitHub repository containing the images
git clone $GITHUB_REPO /home/pi/Marquee

# Install dependencies
apt-get update
apt-get install -y git fbv netcat

# Create marquee.sh script
cat <<'EOL' > /home/pi/marquee.sh
#!/bin/bash

case \$1 in
    GameStart)
        Systemname=\$2
        Romname="\$3"

        if [ -f "/home/pi/Marquee/images/Marquee/hires/\$Romname.jpg" ]; then
            fbv "/home/pi/Marquee/images/Marquee/hires/\$Romname.jpg" -fel
        elif [ -f "/home/pi/Marquee/images/Marquee/\$Systemname/images/\$Romname-marquee.png" ]; then
            fbv "/home/pi/Marquee/images/Marquee/\$Systemname/images/\$Romname-marquee.png" -fel
        else
            fbv /home/pi/Marquee/images/Marquee/default.png -fel
        fi
        ;;
    Gameselected)
        Systemname=\$2
        Romname="\$3"

        if [ -f "/home/pi/Marquee/images/Marquee/\$Systemname/images/\$Romname-marquee.png" ]; then
            fbv "/home/pi/Marquee/images/Marquee/\$Systemname/images/\$Romname-marquee.png" -fel
        else
            fbv /home/pi/Marquee/images/Marquee/default.png -fel
        fi
        ;;
    Systemselected)
        imagepath="/home/pi/Marquee/images/Marquee/sysimages/\$2"

        if [ -f "\$imagepath.png" ]; then
            fbv "\$imagepath.png" -fel
        else
            fbv /home/pi/Marquee/images/Marquee/default.png -fel
        fi
        ;;
esac
EOL

# Make marquee.sh script executable
chmod +x /home/pi/marquee.sh

# Disable first run script
mv /boot/firstrun.sh /boot/firstrun.sh.disabled
EOF

# Make the first run script executable
chmod +x $MOUNT_POINT/firstrun.sh

# Configure Wi-Fi connection for the Pi Zero 2 W
echo "Configuring Wi-Fi..."
cat <<EOF > $MOUNT_POINT/wpa_supplicant.conf
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PSK"
    key_mgmt=WPA-PSK
}
EOF

# Unmount the SD card
echo "Unmounting the SD card..."
umount $MOUNT_POINT

echo "Custom OS image has been flashed and configured on the SD card."
