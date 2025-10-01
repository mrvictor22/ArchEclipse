#!/bin/bash

# Script for automatic fork synchronization with upstream
# Usage: ./sync-upstream-auto.sh
# This script requires no user interaction

set -e

echo "🤖 Automatic synchronization started..."

# Function to clean hanging package manager processes
cleanup_hanging_processes() {
    echo "🧹 Cleaning hanging package manager processes..."
    
    local pacman_pids=$(ps aux | grep -E "(pacman|yay|paru)" | grep -v grep | awk '{print $2}' | tr '\n' ' ')
    
    if [ -n "$pacman_pids" ]; then
        echo "📋 Hanging processes found: $pacman_pids"
        for pid in $pacman_pids; do
            if kill -0 "$pid" 2>/dev/null; then
                sudo kill -TERM "$pid" 2>/dev/null || true
                sleep 1
                if kill -0 "$pid" 2>/dev/null; then
                    sudo kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        done
        
        # Clean hanging pkill
        local stuck_pkill=$(ps aux | grep "pkill.*pacman" | grep -v grep | awk '{print $2}' | tr '\n' ' ')
        if [ -n "$stuck_pkill" ]; then
            for pid in $stuck_pkill; do
                sudo kill -9 "$pid" 2>/dev/null || true
            done
        fi
    fi
    
    # Remove lock file if it exists
    if [ -f /var/lib/pacman/db.lck ]; then
        sudo rm -f /var/lib/pacman/db.lck
    fi
}

# Run preventive cleanup
cleanup_hanging_processes

# Verify we are in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: You are not in a Git repository"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Uncommitted changes detected"
    echo "🔄 Saving changes temporarily with stash..."
    
    # Create stash with descriptive message
    STASH_MESSAGE="Auto-stash before upstream sync $(date '+%Y-%m-%d %H:%M:%S')"
    git stash push -m "$STASH_MESSAGE"
    STASHED=true
    echo "✅ Changes saved in stash"
else
    STASHED=false
fi

# Switch to master if we're not there
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "🔄 Switching to master branch..."
    git checkout master
fi

# Verify upstream exists
if ! git remote get-url upstream > /dev/null 2>&1; then
    echo "❌ Error: Remote 'upstream' not configured"
    echo "💡 Configure it with: git remote add upstream https://github.com/AymanLyesri/ArchEclipse.git"
    exit 1
fi

# Fetch upstream and origin
echo "📥 Fetching changes from upstream and origin..."
git fetch upstream
git fetch origin

# Check if there are changes in upstream
BEHIND_UPSTREAM=$(git rev-list --count HEAD..upstream/master)
if [ "$BEHIND_UPSTREAM" -eq 0 ]; then
    echo "✅ Your fork is already up to date with upstream"
    
    # Check if origin is ahead
    BEHIND_ORIGIN=$(git rev-list --count HEAD..origin/master)
    if [ "$BEHIND_ORIGIN" -gt 0 ]; then
        echo "📥 Synchronizing with origin changes..."
        git merge origin/master --no-edit
        echo "✅ Synchronized with origin"
    fi
    
    # Return to original branch
    if [ "$CURRENT_BRANCH" != "master" ]; then
        git checkout "$CURRENT_BRANCH"
    fi
    exit 0
fi

echo "📊 Your fork is $BEHIND_UPSTREAM commits behind upstream"

# Function to handle merge conflicts automatically
handle_merge_conflicts() {
    local source=$1
    echo "🔧 Attempting to resolve conflicts automatically..."
    
    # Get list of conflicting files
    CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
    
    if [ -z "$CONFLICT_FILES" ]; then
        echo "✅ No conflicts to resolve"
        return 0
    fi
    
    echo "📋 Conflicting files:"
    echo "$CONFLICT_FILES" | sed 's/^/   - /'
    
    # Automatic strategy: accept changes from source (upstream/origin)
    echo "🤖 Resolving automatically by accepting changes from $source..."
    
    for file in $CONFLICT_FILES; do
        if [ "$source" = "upstream" ]; then
            # Accept changes from upstream
            git checkout --theirs "$file"
        else
            # Accept changes from origin
            git checkout --theirs "$file"
        fi
        git add "$file"
        echo "   ✅ Resolved: $file"
    done
    
    # Complete the merge
    git commit --no-edit
    echo "✅ Conflicts resolved and merge completed"
}

# Automatically detect the best strategy
LOCAL_COMMITS=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo "0")
ORIGIN_COMMITS=$(git rev-list --count HEAD..origin/master 2>/dev/null || echo "0")

echo "📋 Analysis:"
echo "   - Local unpushed commits: $LOCAL_COMMITS"
echo "   - Commits in origin not local: $ORIGIN_COMMITS"
echo "   - New commits in upstream: $BEHIND_UPSTREAM"

# Automatic strategy
if [ "$LOCAL_COMMITS" -eq 0 ] && [ "$ORIGIN_COMMITS" -eq 0 ]; then
    echo "🚀 Strategy: Fast-forward merge (no local commits)"
    STRATEGY="merge"
    git merge upstream/master --ff-only
elif [ "$LOCAL_COMMITS" -gt 0 ] && [ "$ORIGIN_COMMITS" -eq 0 ]; then
    echo "🔄 Strategy: Rebase (local commits present)"
    STRATEGY="rebase"
    git rebase upstream/master
else
    echo "🔀 Strategy: Merge (complex situation)"
    STRATEGY="merge"
    # First synchronize with origin if necessary
    if [ "$ORIGIN_COMMITS" -gt 0 ]; then
        echo "📥 Synchronizing first with origin..."
        if ! git merge origin/master --no-edit; then
            echo "⚠️  Conflicts detected when merging with origin"
            handle_merge_conflicts "origin"
        fi
    fi
    
    if ! git merge upstream/master --no-edit; then
        echo "⚠️  Conflicts detected when merging with upstream"
        handle_merge_conflicts "upstream"
    fi
fi

# Improved function for automatic push
auto_push() {
    local max_retries=3
    local retry=0
    
    echo "📤 Pushing changes automatically..."
    
    while [ $retry -lt $max_retries ]; do
        # Try normal push first
        if git push origin master; then
            echo "✅ Push successful"
            return 0
        fi
        
        echo "⚠️  Push failed (attempt $((retry + 1))/$max_retries)"
        
        # Fetch origin to see what happened
        git fetch origin master
        
        # Check the situation
        if git merge-base --is-ancestor HEAD origin/master; then
            # We're ahead, something weird happened, use force-with-lease
            echo "🔄 Using force-with-lease..."
            if git push origin master --force-with-lease; then
                echo "✅ Push with force-with-lease successful"
                return 0
            fi
        else
            # Origin has changes we don't have
            echo "🔄 Origin has new changes, integrating..."
            
            if [ "$STRATEGY" = "rebase" ]; then
                git rebase origin/master
            else
                git merge origin/master --no-edit
            fi
        fi
        
        retry=$((retry + 1))
    done
    
    echo "❌ Error: Could not push after $max_retries attempts"
    echo "💡 Review manually: git log --oneline --graph --all"
    return 1
}

# Execute automatic push
if ! auto_push; then
    exit 1
fi

# Return to original branch if it was different
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "🔄 Returning to branch $CURRENT_BRANCH..."
    git checkout "$CURRENT_BRANCH"
fi

# Restore changes from stash if there were any
if [ "$STASHED" = true ]; then
    echo "🔄 Restoring changes from stash..."
    if git stash pop; then
        echo "✅ Changes restored successfully"
    else
        echo "⚠️  There are conflicts when restoring the stash"
        echo "💡 Resolve conflicts manually and then run: git stash drop"
    fi
fi

echo "✅ Automatic synchronization completed!"
if [ "$BEHIND_UPSTREAM" -gt 0 ]; then
    echo "📊 Changes applied: $BEHIND_UPSTREAM commits from upstream"
    echo "🎯 Strategy used: $STRATEGY"
else
    echo "📊 There were no new changes in upstream"
fi
