#!/bin/bash

# Script to synchronize fork with upstream
# Usage: ./sync-upstream.sh

set -e

echo "🔄 Synchronizing fork with upstream..."

# Verify we are in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: You are not in a Git repository"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"

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

# Fetch upstream
echo "📥 Fetching changes from upstream..."
git fetch upstream

# Check if there are changes
BEHIND=$(git rev-list --count HEAD..upstream/master)
if [ "$BEHIND" -eq 0 ]; then
    echo "✅ Your fork is already up to date"
    exit 0
fi

echo "📊 Your fork is $BEHIND commits behind upstream"

# Ask user which method to use
echo "How do you want to synchronize?"
echo "1) Merge (preserves complete history)"
echo "2) Rebase (cleaner history)"
echo "3) Automatic (detects the best option)"
read -p "Select (1, 2 or 3): " CHOICE

case $CHOICE in
    1)
        echo "🔀 Merging..."
        git merge upstream/master --no-edit
        ;;
    2)
        echo "🔄 Rebasing..."
        git rebase upstream/master
        ;;
    3)
        echo "🤖 Automatic mode activated..."
        # Check if there are unpushed local commits
        LOCAL_COMMITS=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo "0")
        
        if [ "$LOCAL_COMMITS" -eq 0 ]; then
            echo "📋 No local commits, using fast merge..."
            CHOICE=1
            git merge upstream/master --no-edit
        else
            echo "📋 There are $LOCAL_COMMITS local commits, using rebase for clean history..."
            CHOICE=2
            git rebase upstream/master
        fi
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

# Push changes
echo "📤 Pushing changes to your fork..."

# Function to handle push with retries
push_changes() {
    local method=$1
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if [ "$method" -eq 2 ]; then
            # For rebase, use force-with-lease
            if git push origin master --force-with-lease; then
                return 0
            fi
        else
            # For merge, try normal push first
            if git push origin master; then
                return 0
            fi
        fi
        
        # If push fails, try synchronizing with origin first
        echo "⚠️  Push failed, synchronizing with remote origin..."
        
        # Fetch origin to get remote changes
        git fetch origin master
        
        # Check if there are conflicts
        if git merge-base --is-ancestor HEAD origin/master; then
            # Our changes are ahead, use force-with-lease
            echo "🔄 Using force-with-lease to overwrite remote changes..."
            if git push origin master --force-with-lease; then
                return 0
            fi
        else
            # There are changes in origin we don't have
            echo "🔄 Integrating changes from remote origin..."
            
            if [ "$method" -eq 2 ]; then
                # With rebase, rebase on origin/master
                git rebase origin/master
            else
                # With merge, merge origin/master
                git merge origin/master --no-edit
            fi
        fi
        
        retry=$((retry + 1))
        echo "🔄 Retry $retry of $max_retries..."
    done
    
    echo "❌ Error: Could not push after $max_retries attempts"
    return 1
}

# Call push function
if ! push_changes "$CHOICE"; then
    echo "💡 Suggestion: Review changes manually with 'git log --oneline --graph'"
    exit 1
fi

# Return to original branch if it was different
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "🔄 Returning to branch $CURRENT_BRANCH..."
    git checkout "$CURRENT_BRANCH"
fi

echo "✅ Synchronization completed!"
echo "📊 Changes applied: $BEHIND commits"
