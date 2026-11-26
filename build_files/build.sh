#!/bin/bash

set -ouex pipefail

### Add third-party yum repos used by the package set
cat > /etc/yum.repos.d/atim-starship.repo <<'EOF'
[copr:starship]
name=Copr repo for starship owned by atim
baseurl=https://copr-be.cloud.fedoraproject.org/results/atim/starship/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
enabled=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/atim/starship/pubkey.gpg
EOF

cat > /etc/yum.repos.d/kopia.repo <<'EOF'
[Kopia]
name=Kopia
baseurl=http://packages.kopia.io/rpm/stable/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://kopia.io/signing-key
EOF

cat > /etc/yum.repos.d/varlad-zellij.repo <<'EOF'
[copr:zellij]
name=Copr repo for zellij owned by varlad
baseurl=https://copr-be.cloud.fedoraproject.org/results/varlad/zellij/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
enabled=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/varlad/zellij/pubkey.gpg
EOF

### Install packages from enabled repos
# The package set is based on the CoreOS-derived package list, excluding personal user config.
dnf5 install -y \
    atuin bat chezmoi fd-find git-delta helix \
    kopia lsd nu podman-compose ripgrep rustup \
    starship syncthing tailscale tealdeer zellij \
    zsh zsh-autosuggestions zsh-syntax-highlighting

# Build tools for the out-of-tree it87 kernel module.
dnf5 group install -y development-tools

# Build the module against the kernel shipped in the base image, then install
# it so it loads at boot in place of the in-tree it87 driver.
/ctx/build-it87.sh

# Enable a useful socket-enabled service example from the template
systemctl enable podman.socket
