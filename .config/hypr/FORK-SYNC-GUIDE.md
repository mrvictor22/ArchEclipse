# 🔄 Fork Synchronization Guide

This guide explains how to use the automatic synchronization tools to keep your fork updated with Ayman's upstream repository.

## 📋 Available Tools

### 1. `sync-upstream.sh` - Interactive Script
Script with interactive options for different synchronization strategies.

### 2. `sync-upstream-auto.sh` - Automatic Script
Fully automatic script that requires no user interaction.

### 3. GitHub Action - Daily Synchronization
Automatic action that runs daily to keep the fork updated.

---

## 🚀 Usage Commands

### Interactive Synchronization

```bash
# Run interactive script
./sync-upstream.sh

# Available options:
# 1) Merge (preserves complete history)
# 2) Rebase (cleaner history)  
# 3) Automatic (detects the best option)
```

### Automatic Synchronization

```bash
# Run fully automatic synchronization
./sync-upstream-auto.sh

# This script:
# - Automatically saves local changes to stash
# - Detects the best strategy (merge/rebase)
# - Automatically resolves conflicts
# - Handles push errors
# - Restores local changes at the end
```

### Manual Verification

```bash
# Check if updates are available (without applying)
git fetch upstream && git log --oneline HEAD..upstream/master

# View differences before synchronizing
git fetch upstream && git diff HEAD upstream/master

# Check current repository status
git status

# View commit history
git log --oneline --graph --all -10
```

### Emergency Commands

```bash
# If something goes wrong, abort merge in progress
git merge --abort

# If there are conflicts, view affected files
git diff --name-only --diff-filter=U

# Restore from stash if necessary
git stash list
git stash pop

# Force push if necessary (use with caution)
git push origin master --force-with-lease
```

---

## 🔧 Initial Configuration

### Verify Remote Configuration

```bash
# View configured remotes
git remote -v

# Should show:
# origin    https://github.com/mrvictor22/ArchEclipse.git (fetch)
# origin    https://github.com/mrvictor22/ArchEclipse.git (push)
# upstream  https://github.com/AymanLyesri/ArchEclipse.git (fetch)
# upstream  https://github.com/AymanLyesri/ArchEclipse.git (push)
```

### If Upstream Is Not Configured

```bash
# Add upstream remote
git remote add upstream https://github.com/AymanLyesri/ArchEclipse.git

# Verify it was added correctly
git remote -v
```

---

## 📊 Recommended Workflow

### Daily Use

1. **Quick verification** (optional):
   ```bash
   git fetch upstream && git log --oneline HEAD..upstream/master
   ```

2. **Automatic synchronization**:
   ```bash
   ./sync-upstream-auto.sh
   ```

### Weekly Use

1. **Interactive synchronization** for more control:
   ```bash
   ./sync-upstream.sh
   ```

2. **Select strategy** according to your needs:
   - **Merge**: If you want to preserve full history
   - **Rebase**: If you prefer cleaner history
   - **Automatic**: Let the script decide

---

## 🤖 GitHub Action - Automatic Synchronization

### Configuration

The GitHub Action is configured in `.github/workflows/sync-upstream.yml` and:

- **Runs automatically** every day at 2:00 AM UTC
- **Can be run manually** from the "Actions" tab on GitHub
- **Uses merge strategy** to preserve history
- **Automatically pushes** changes

### Run Manually from GitHub

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. Select "Sync Upstream"
4. Click on "Run workflow"
5. Confirm with "Run workflow"

---

## ⚠️ Troubleshooting

### Error: "non-fast-forward"

```bash
# The automatic script handles this, but if it occurs manually:
git fetch origin
git merge origin/master --no-edit
git push origin master
```

### Merge Conflicts

```bash
# View conflicting files
git status

# For each conflicting file, choose a strategy:
git checkout --ours archivo.conf    # Keep your version
git checkout --theirs archivo.conf  # Accept upstream version

# Mark as resolved and complete merge
git add archivo.conf
git commit --no-edit
```

### Stash with Conflicts

```bash
# If there are conflicts when restoring stash
git stash list
git stash show stash@{0}

# Resolve conflicts manually and then:
git stash drop stash@{0}
```

---

## 📈 Monitoring and Logs

### View Latest Synchronized Changes

```bash
# View recent commits
git log --oneline -10

# View upstream specific changes
git log --oneline upstream/master -5

# View differences between your fork and upstream
git log --oneline --left-right HEAD...upstream/master
```

### Verify Synchronization Status

```bash
# Check if you're up to date
git fetch upstream
git status

# See how many commits you're ahead/behind
git rev-list --count HEAD..upstream/master  # Behind
git rev-list --count upstream/master..HEAD  # Ahead
```

---

## ⚠️ **IMPORTANT: Difference between Normal Update vs Fork Update**

### ❌ **"Normal" Update (DANGEROUS for forks)**
```bash
# THESE COMMANDS TAKE YOU TO UPSTREAM ONLY WITHOUT YOUR CHANGES
git checkout upstream/master     # ❌ You lose your improvements
git reset --hard upstream/master # ❌ You lose your improvements  
git pull upstream master         # ❌ Without proper merge
```
**⚠️ These commands would DELETE all your improvements, scripts, and custom configurations!**

### ✅ **Correct Fork Update (Keeps your changes)**
```bash
# THESE ARE THE CORRECT COMMANDS FOR YOUR FORK
./sync-upstream-auto.sh          # ✅ Automatic, keeps your changes
./sync-upstream.sh               # ✅ Interactive, keeps your changes
```

### 🔍 **Why the difference?**

- **Your fork** has additional improvements (sync scripts, documentation, configurations)
- **Upstream** only has Ayman's base changes
- **The sync scripts** combine both: upstream + your improvements
- **Normal update** would take you only to the base state, losing your work

### 📊 **Current Status of Your Fork:**
```bash
# Your fork includes:
- Ayman's base changes (upstream)
- Automatic synchronization scripts
- Complete documentation
- Custom configurations
- Multi-monitor improvements
- And much more...
```

## 🎯 Best Practices

1. **ALWAYS use sync scripts** to update
2. **NEVER use git reset --hard upstream/master**
3. **Run synchronization regularly** (daily or weekly)
4. **Use the automatic script** for routine use
5. **Use the interactive script** when you want more control
6. **Verify changes** before synchronizing if you have important work
7. **Keep local commits organized** to avoid conflicts
8. **Use branches** for experimental development

---

## 📞 Support

If you encounter problems:

1. **Review the logs** from the script to understand what happened
2. **Use verification commands** to diagnose the state
3. **Consult this guide** for emergency commands
4. **As a last resort**, backup your changes and clone fresh

---

*Last updated: 2025-09-28*
*Tool version: 6d9a16d*
