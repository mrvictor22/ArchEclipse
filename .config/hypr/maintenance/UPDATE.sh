#!/bin/bash

MAINTENANCE_DIR="$HOME/.config/hypr/maintenance"

# Parse arguments
DEV_MODE=false
USE_UPSTREAM=false
BRANCH=""
REMOTE="origin"

for arg in "$@"; do
    case $arg in
        --dev)
            DEV_MODE=true
            shift
            ;;
        --upstream)
            USE_UPSTREAM=true
            REMOTE="upstream"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [BRANCH]"
            echo ""
            echo "Options:"
            echo "  --dev        Developer mode: preserves local changes and current branch"
            echo "  --upstream   Use upstream repository instead of your fork"
            echo "  --help       Show this help message"
            echo ""
            echo "Arguments:"
            echo "  BRANCH       Git branch to update from (default: current branch in dev mode, master otherwise)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Normal update from your fork (origin/master)"
            echo "  $0 --dev             # Developer update preserving current branch and changes"
            echo "  $0 --upstream        # Update from upstream (AymanLyesri/ArchEclipse)"
            echo "  $0 --dev --upstream  # Developer mode using upstream"
            echo "  $0 --upstream develop # Update from upstream/develop"
            echo ""
            echo "Repository modes:"
            echo "  Default:    Updates from your fork (mrvictor22/ArchEclipse)"
            echo "  --upstream: Updates from upstream (AymanLyesri/ArchEclipse)"
            echo "  --dev:      Preserves current branch and local changes"
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

# Set branch logic
if [ "$DEV_MODE" = true ]; then
    if [ -z "$BRANCH" ]; then
        CURRENT_BRANCH=$(git branch --show-current)
        BRANCH="$CURRENT_BRANCH"
        echo "🔧 Developer mode: staying on current branch '$BRANCH'"
    else
        echo "🔧 Developer mode: switching to specified branch '$BRANCH'"
    fi
else
    if [ -z "$BRANCH" ]; then
        BRANCH="master"
    fi
fi

# Display current mode
if [ "$DEV_MODE" = true ] && [ "$USE_UPSTREAM" = true ]; then
    echo "🔧⬆️ Developer mode + Upstream: preserving changes, using upstream"
elif [ "$DEV_MODE" = true ]; then
    echo "🔧🍴 Developer mode: preserving local changes from your fork"
elif [ "$USE_UPSTREAM" = true ]; then
    echo "⬆️ Upstream mode: updating from upstream (AymanLyesri/ArchEclipse)"
else
    echo "🍴 Fork mode: updating from your fork (default)"
fi

echo "📍 Repository: $REMOTE"
echo "🌿 Branch: $BRANCH"

source $HOME/.config/hypr/maintenance/ESSENTIALS.sh # source the essentials file INSIDE the repository

# Developer mode: save local changes before updating
if [ "$DEV_MODE" = true ]; then
    echo "💾 Saving local changes..."
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️  No local changes to save"
    else
        git add -A 2>/dev/null || true
        if git stash push -m "Auto-stash before dev update $(date)" 2>/dev/null; then
            echo "✅ Local changes saved successfully"
        else
            echo "⚠️  Could not save local changes, continuing anyway..."
        fi
    fi
fi

# Only checkout if we're not already on the target branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    git checkout $BRANCH
fi

git fetch $REMOTE $BRANCH

# In dev mode, merge instead of hard reset to preserve work
if [ "$DEV_MODE" = true ]; then
    echo "🔄 Merging updates from $REMOTE/$BRANCH..."
    git merge $REMOTE/$BRANCH --no-edit
else
    git reset --hard $REMOTE/$BRANCH
fi

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
            echo "🔄 Continuing with the update process..."
        fi
    else
        echo "ℹ️  No local changes to restore"
    fi
    echo "📋 Proceeding with maintenance scripts..."
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
