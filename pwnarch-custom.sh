#!/bin/bash

# Store list of local BlackArch packages in a variable for later use
blackarchpkgs=(\$(pacman -Sg blackarch | cut -d' ' -f2- | sed -e 's\/^\/\\/var\\/cache\\/pacman\\/pkg\/g' | sed -e 's\/$\/\.pkg\.tar\.\*/g'))

# BlackArch repo setup
wget -O /tmp/blackarch-strap.sh https://blackarch.org/strap.sh
chmod a+x /tmp/blackarch-strap.sh
/tmp/blackarch-strap.sh

# BlackArch tooling: First download, then install, in order to avoid dependency hell
pacman --noconfirm -Sw --needed blackarch --ignore yay
pacman --noconfirm -U --needed --overwrite=* \$\{blackarchpkgs\[\@\]\}

# Reset keyrings
rm -rf /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux blackarch

# Plymouth
sed -i "s/HOOKS.*/HOOKS\=\(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck\)/" /etc/mkinitcpio.conf
plymouth-set-default-theme -R bgrt

# SDDM
sed -i "s/Relogin\=false/Relogin\=true/" /usr/lib/sddm/sddm.conf.d/default.conf
sed -i "s/Session\=/Session\=plasma.desktop/" /usr/lib/sddm/sddm.conf.d/default.conf
sed -i "s/User\=/User\=pwnarch/" /usr/lib/sddm/sddm.conf.d/default.conf

# AUR helpers, part 1
cat > /home/pwnarch/aur.sh <<-EOF2
	#!/bin/bash
	mkdir -p ~/.cache/yay
	cd ~/.cache/yay
	git clone https://aur.archlinux.org/yay-git.git
	cd yay-git
	yes | makepkg -si
EOF2

# AUR helpers, part 2
chmod a+x /home/pwnarch/aur.sh
chown pwnarch:pwnarch /home/pwnarch/aur.sh
sudo -u pwnarch /home/pwnarch/aur.sh
rm /home/pwnarch/aur.sh

# AUR Installs
sudo -u pwnarch yay --noconfirm -S google-chrome-dev visual-studio-code-insiders-bin rate-mirrors-bin havoc-c2-git wordlists

# Automatic updates, part 1
cat > /lib/systemd/system/autoupdate.service <<-EOF2
	[Unit]
	Description=Automatic Update
	After=network-online.target

	[Service]
	Type=simple
	SyslogIdentifier=autoupdate
	ExecStart=/usr/bin/sudo -u pwnarch /usr/bin/yay -Syuq --noconfirm --devel --timeupdate
	TimeoutStopSec=300
	KillMode=process
	KillSignal=SIGINT

	[Install]
	WantedBy=multi-user.target
EOF2

# Automatic updates, part 2
cat > /lib/systemd/system/autoupdate.timer <<-EOF2
[Unit]
	Description=Automatic Update

	[Timer]
	OnBootSec=1min
	OnActiveSec=5min
	OnUnitActiveSec=1h
	Unit=autoupdate.service

	[Install]
	WantedBy=multi-user.target
EOF2

# Automatic updates, part 3
systemctl enable autoupdate.timer

# Make Reflector run automatically, Part 1
cat > /etc/xdg/reflector/reflector.conf <<-EOF2
	-c "United States"
	--sort rate
	--save /etc/pacman.d/mirrorlist
EOF2

# Make Reflector run automatically, Part 2
cat > /lib/systemd/system/reflector.timer <<-EOF2
	[Unit]
	Description=Refresh Pacman mirrorlist hourly with Reflector.

	[Timer]
	OnCalendar=hourly
	Persistent=true
	AccuracySec=1us
	RandomizedDelaySec=1h

	[Install]
	WantedBy=timers.target
EOF2

# Make Reflector run automatically, Part 3
systemctl enable reflector.timer

# PwnBox-style shell prompts, Part 3
cat /etc/bash.bashrc > /home/pwnarch/.bashrc

# Nvidia graphics: update modules on kernel update
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/nvidia.hook <<-EOF2
	[Trigger]
	Operation=Install
	Operation=Upgrade
	Operation=Remove
	Type=Package
	# Uncomment the installed NVIDIA package
	#Target=nvidia
	Target=nvidia-dkms
	#Target=nvidia-lts
	# If running a different kernel, modify below to match
	Target=linux-zen

	[Action]
	Description=Updating NVIDIA module in initcpio
	Depends=mkinitcpio
	When=PostTransaction
	NeedsTargets
	Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF2
