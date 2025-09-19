#!/bin/bash

MAINTENANCE_DIR="$HOME/.config/hypr/maintenance"

# Parse arguments
DEV_MODE=false
USE_FORK=false
BRANCH="master"
REMOTE="upstream"

for arg in "$@"; do
    case $arg in
        --dev)
            DEV_MODE=true
            shift
            ;;
        --fork)
            USE_FORK=true
            REMOTE="origin"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [BRANCH]"
            echo ""
            echo "Options:"
            echo "  --dev     Developer mode: preserves local changes during update"
            echo "  --fork    Use forked repository instead of upstream"
            echo "  --help    Show this help message"
            echo ""
            echo "Arguments:"
            echo "  BRANCH    Git branch to update from (default: master)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Normal update from upstream/master"
            echo "  $0 --dev             # Developer update preserving local changes"
            echo "  $0 --fork            # Update from your fork (origin/master)"
            echo "  $0 --dev --fork      # Developer mode using your fork"
            echo "  $0 --fork develop    # Update from origin/develop"
            echo ""
            echo "Repository modes:"
            echo "  Default: Updates from upstream (AymanLyesri/ArchEclipse)"
            echo "  --fork:  Updates from your fork (mrvictor22/ArchEclipse)"
            exit 0
            ;;
        *)
            if [[ ! "$arg" =~ ^-- ]]; then
                BRANCH="$arg"
            fi
            ;;
    esac
done

figlet "Updating Config"

# Display current mode
if [ "$DEV_MODE" = true ] && [ "$USE_FORK" = true ]; then
    echo "🔧🍴 Developer mode + Fork: preserving changes, using your fork"
elif [ "$DEV_MODE" = true ]; then
    echo "🔧 Developer mode: preserving local changes from upstream"
elif [ "$USE_FORK" = true ]; then
    echo "🍴 Fork mode: updating from your fork (origin)"
else
    echo "📦 Standard mode: updating from upstream"
fi

echo "📍 Repository: $REMOTE"
echo "🌿 Branch: $BRANCH"

source $HOME/.config/hypr/maintenance/ESSENTIALS.sh # source the essentials file INSIDE the repository

# Developer mode: save local changes before updating
if [ "$DEV_MODE" = true ]; then
    echo "💾 Saving local changes..."
    git add -A 2>/dev/null || true
    git stash push -m "Auto-stash before dev update $(date)" 2>/dev/null || true
fi

git checkout $BRANCH
git fetch $REMOTE $BRANCH
git reset --hard $REMOTE/$BRANCH

# Developer mode: restore local changes after update
if [ "$DEV_MODE" = true ]; then
    echo "🔄 Restoring local changes..."
    if git stash list | grep -q "Auto-stash before dev update"; then
        if git stash pop; then
            echo "✅ Local changes restored successfully"
        else
            echo "⚠️  Merge conflicts detected. Please resolve manually with:"
            echo "   git status"
            echo "   git add <resolved-files>"
            echo "   git stash drop"
        fi
    else
        echo "ℹ️  No local changes to restore"
    fi
fi

# Kill any hanging pacman processes and clean lock file
echo "Cleaning up any hanging pacman processes..."
sudo pkill -f pacman 2>/dev/null || true
sudo pkill -f yay 2>/dev/null || true
sudo pkill -f paru 2>/dev/null || true

# Remove pacman lock file if it exists
if [ -f /var/lib/pacman/db.lck ]; then
    echo "Removing pacman lock file..."
    sudo rm -f /var/lib/pacman/db.lck
fi

aur_helpers=("yay" "paru")

for helper in "${aur_helpers[@]}"; do
    if command -v "$helper" &>/dev/null; then
        aur_helper="$helper"
        break
    fi
done

if [[ -z "$aur_helper" ]]; then
    echo "No AUR helper (yay or paru) is installed."
else
    continue_prompt "Do you want to update necessary packages? (using $aur_helper)" "$HOME/.config/hypr/pacman/install-pkgs.sh $aur_helper"
fi

# $MAINTENANCE_DIR/AGSV1.sh
if pacman -Q agsv1 &>/dev/null; then
    yay -Rns agsv1 --noconfirm
fi

$MAINTENANCE_DIR/WALLPAPERS.sh

$MAINTENANCE_DIR/WAL.sh

$MAINTENANCE_DIR/PLUGINS.sh

$MAINTENANCE_DIR/TWEAKS.sh
