#!/bin/bash

shopt -s extglob

isodir=/var/tmp/work
archisocfgdir=$PWD


if [ -z "$1" ]
then
  echo "Usage: ./build.sh COUNTRY_CODE, where COUNTRY_CODE is the ISO 3166-1 alpha-2 code (i.e. \"US\") for the country in which you reside"
  exit 1
fi

mirror_country=$1

# Use nixpkgs to allow people to build ISO images on non-Arch host systems
nix_setup() {
  bash <(curl -L https://nixos.org/nix/install) --no-channel-add --daemon --yes
  source /etc/bashrc || source /etc/bash.bashrc
  nix-channel --add https://github.com/NixOS/nixpkgs/archive/master.tar.gz nixpkgs
  nix-channel --update nixpkgs
}

nix_cleanup() {
  sudo systemctl disable --now nix-daemon.socket nix-daemon.service
  sudo systemctl daemon-reload

  for i in $(seq 1 32); do
      sudo userdel nixbld$i
  done
  sudo groupdel nixbld

  sudo find /etc -iname "*.backup-before-nix" -delete
  sudo rm -rf /etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf /nix ~root/.nix-channels ~root/.nix-defexpr ~root/.nix-profile
}

cleanup() {
  for aurpkg in calamares-git rate-mirrors-bin havoc-c2-git wordlists; do
    sudo rm -rf $aurpkg
  done

  sudo rm -rf $isodir
  sudo rm -rf $PWD/airootfs/usr/share/pwnarch

  if [ ! -f /etc/os-release ] || [ -z "$(grep 'Arch' /etc/os-release)" ]
  then
    sudo pacman -R arch-install-scripts
    nix_cleanup
  fi
}

fail() {
  cleanup
  exit 1
}

if [ ! -f /etc/os-release ] || [ -z "$(grep 'Arch' /etc/os-release)" ]
then
  # If the non-Arch host is NixOS, skip this step
  if [ -z "$(which nixos-rebuild)" ]
  then
    nix_setup
  fi

  # This pulls in pacman as a dependency
  sudo bash -c 'nix-env -iA nixpkgs.{arch-install-scripts,dosfstools,e2fsprogs,erofs-utils,squashfs-tools-ng,libarchive,libisoburn,mtools}'

  # Other things need to be setup on non-Arch hosts for this to work
  if [ ! -d /etc/pacman.d ]
  then
    mkdir -p /etc/pacman.d
    wget -qO - "https://archlinux.org/mirrorlist/?country=$mirror_country&protocol=http&protocol=https&ip_version=4&ip_version=6&use_mirror_status=on" | sed 's/#Server/Server/g' | sudo tee /etc/pacman.d/mirrorlist
  elif [ ! -f /etc/pacman.d/mirrorlist ]
  then
    wget -qO - "https://archlinux.org/mirrorlist/?country=$mirror_country&protocol=http&protocol=https&ip_version=4&ip_version=6&use_mirror_status=on" | sed 's/#Server/Server/g' | sudo tee /etc/pacman.d/mirrorlist
  fi

  cp ./pacman.conf /etc/pacman.conf
fi

# Main dependency
sudo pacman --noconfirm --needed --nodeps -Sy archiso

# Create custom AUR repository (if it doesn't already exist)
if [ ! -d /var/tmp/aurpkgs ]
then
  mkdir /var/tmp/aurpkgs

  for aurpkg in calamares-git rate-mirrors-bin havoc-c2-git wordlists
  do
    git clone https://aur.archlinux.org/$aurpkg.git || fail
    cd $aurpkg
    makepkg --noconfirm -s || fail
    mv -f *.pkg.tar.zst /var/tmp/aurpkgs
    cd ..
    rm -rf $aurpkg
  done

  cd /var/tmp/aurpkgs
  repo-add aurpkgs.db.tar.xz *.pkg.tar.zst
  cd $archisocfgdir
fi

# Fix signature issues
sudo sed -i 's/^pacman_args\=.*/pacman_args\=(--overwrite=* --gpgdir\=$newroot\/etc\/pacman\.d\/gnupg)/' $(which pacstrap)

# Many BlackArch packages require an Internet connection to bootstrap
sudo cp -f /etc/resolv.conf $PWD/airootfs/etc/resolv.conf

# Ensure reproducibility
cp -r $PWD /var/tmp/pwnarch
sudo mv -f /var/tmp/pwnarch $PWD/airootfs/usr/share/pwnarch

# Copy files
sudo cp -r $PWD $isodir

# Import ISO image signing key
sudo gpg --import sig.key

# Create ISO image
sudo mkarchiso -v -w $isodir -g 257E2401871A483C -o .. . -r || fail

cleanup
