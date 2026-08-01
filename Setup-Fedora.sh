#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# TUI icons
ICON_ROCKET="🚀"
ICON_LIGHTNING="⚡"
ICON_REFRESH="🔄"
ICON_PACKAGE="📦"
ICON_GAME="🎮"
ICON_VIDEO="🎥"
ICON_GAME2="🕹️"
ICON_WORLD="🌍"
ICON_BRAIN="🧠"
ICON_CHECK="✅"
ICON_WARNING="⚠️"
ICON_ERROR="❌"

# Colors
NC='\033[0m'
BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[97m'

info(){ echo -e "${CYAN}${1}${NC}"; }
success(){ echo -e "${GREEN}${1}${NC}"; }
warn(){ echo -e "${YELLOW}${1}${NC}"; }
err(){ echo -e "${RED}${1}${NC}"; }

pause() {
    echo
    read -n 1 -s -r -p "$(echo -e \"${BOLD}${BLUE}Press any key to continue...${NC}\")"
    echo
}

info "${ICON_ROCKET} Starting Fedora 43 Gaming Setup for RTX 4090..."
info "This is a multi-stage setup script. It will reboot your system multiple times to ensure proper driver installation and configuration."

pause

# Path to the state file to track progress across reboots
STATE_FILE="$HOME/.fedora_setup_stage"
[ ! -f "$STATE_FILE" ] && echo "1" > "$STATE_FILE"

STAGE=$(cat "$STATE_FILE")
OVERRIDE_STAGE=""

usage() {
    echo "Usage: $0 [--stage N]"
    echo
    echo "Options:"
    echo "  --stage N   Run only stage N (1-4) and do not use saved state."
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stage)
                shift
                if [[ $# -eq 0 || ! "$1" =~ ^[1-4]$ ]]; then
                    err "${ICON_ERROR} Invalid stage: $1"
                    usage
                fi
                OVERRIDE_STAGE="$1"
                shift
                ;;
            -*|--*)
                err "${ICON_ERROR} Unknown option: $1"
                usage
                ;;
            *)
                err "${ICON_ERROR} Unexpected argument: $1"
                usage
                ;;
        esac
    done
}

error_exit() {
    err "${ICON_ERROR} Error occurred at Stage ${DISPATCH_STAGE:-$STAGE}. Check logs."
    exit 1
}

set_stage_and_reboot() {
    local next_stage="$1"
    echo "$next_stage" > "$STATE_FILE"
    success "${ICON_CHECK} $2"
    sudo reboot
}

stage_one() {
    info "${ICON_REFRESH} --- STAGE 1: Repository Setup and System Update ---"

    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER >/dev/null && sudo chmod 0440 /etc/sudoers.d/$USER

    info "${ICON_LIGHTNING} Optimizing DNF5..."
    sudo sed -i 's/\[main\]/\[main\]\nmax_parallel_downloads=10/' /etc/dnf/dnf.conf

    sudo dnf5 install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    sudo dnf5 group upgrade core -y
    sudo dnf5 update -y

    set_stage_and_reboot 2 "System updated. Rebooting to initialize new kernel..."
}

stage_two() {
    info "${ICON_PACKAGE} --- STAGE 2: Firmware and Flatpak Configuration ---"

    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates -y
    sudo fwupdmgr update -y

    flatpak remote-delete fedora --force
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    set_stage_and_reboot 3 "Firmware updated. Rebooting to apply hardware changes..."
}

stage_three() {
    info "${ICON_GAME} --- STAGE 3: NVIDIA Driver Installation ---"

    sudo dnf5 install -y kernel-devel kernel-headers gcc make dkms acpid \
        libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig

    sudo sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'

    sudo dnf5 install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

    info "Waiting for Akmods to build the Nvidia kernel module..."
    warn "This can take 5-10 minutes. Do not cancel."

    while [[ $(ps aux | grep -i "[a]kmods" | wc -l) -gt 0 ]]; do
        sleep 10
        info "Still building..."
    done

    info "${ICON_BRAIN} Tweaking system for 4090 performance..."
    echo "vm.max_map_count=2147483642" | sudo tee /etc/sysctl.d/90-gaming.conf
    sudo sysctl -p /etc/sysctl.d/90-gaming.conf

    set_stage_and_reboot 4 "Nvidia drivers installed and built. Rebooting to activate drivers..."
}

stage_four() {
    info "${ICON_VIDEO} --- STAGE 4: Multimedia, Apps, and Optimization ---"

    sudo dnf5 swap -y ffmpeg-free ffmpeg --allowerasing

    sudo dnf5 install -y gstreamer1-plugins-{bad-\*,good-\*,base} \
        gstreamer1-plugin-openh264 gstreamer1-libav lame\* \
        --exclude=gstreamer1-plugins-bad-free-devel
    sudo dnf5 group install -y multimedia sound-and-video

    sudo dnf5 install -y ffmpeg-libs libva libva-utils libva-nvidia-driver
    sudo dnf5 config-manager --set-enabled fedora-cisco-openh264
    sudo dnf5 update -y

    sudo dnf5 install -y curl cabextract xorg-x11-font-utils fontconfig
    sudo rpm -i --nodigest --nosignature https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
    sudo fc-cache -fv

    sudo dnf5 install -y fuse fuse-libs
    flatpak install -y flathub it.mijorus.gearlever

    sudo tee /etc/systemd/system/flatpak-update.service > /dev/null <<'EOF'
[Unit]
Description=Update Flatpak apps automatically
[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --noninteractive
EOF

    sudo tee /etc/systemd/system/flatpak-update.timer > /dev/null <<'EOF'
[Unit]
Description=Run Flatpak update every 24 hours
[Timer]
OnBootSec=120
OnUnitActiveSec=24h
[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now flatpak-update.timer
    sudo systemctl disable NetworkManager-wait-online.service

    sudo dnf5 install -y steam vlc
    flatpak install -y flathub com.github.tchx84.Flatseal

    echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf
    echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode

    sudo dnf install -y git git-credential-libsecret
    sudo dnf copr enable -y matthickford/git-credential-manager
    sudo dnf install -y git-credential-manager
    git config --global credential.helper "/usr/bin/git-credential-manager"
    git config --global credential.credentialStore libsecret

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    sudo dnf check-update
    sudo dnf install -y code

    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER

    sudo dnf install -y easyeffects

    sudo dnf5 autoremove -y
    sudo dnf5 clean all

    finalize_setup
}

finalize_setup() {
    rm "$STATE_FILE"
    echo -e "${BOLD}${GREEN}----------------------------------------------------${NC}"
    success "${ICON_CHECK} SETUP COMPLETE! Your Fedora 43 system is ready."
    echo -e "${BOLD}${GREEN}----------------------------------------------------${NC}"
}

dispatch_stage() {
    DISPATCH_STAGE="$1"
    case "$1" in
        1) stage_one ;;
        2) stage_two ;;
        3) stage_three ;;
        4) stage_four ;;
        *)
            err "${ICON_ERROR} Invalid stage: $1"
            usage
            ;;
    esac
}

main() {
    parse_args "$@"

    if [[ -n "$OVERRIDE_STAGE" ]]; then
        dispatch_stage "$OVERRIDE_STAGE"
    else
        dispatch_stage "$STAGE"
    fi
}

main "$@"
