# 🔄 Fork Sync Tools - Quick Reference

Tools to keep your fork synchronized with Ayman's upstream repository.

## 🚀 Main Commands

### ✅ **To Update While Keeping YOUR Changes (RECOMMENDED)**

```bash
# Automatic synchronization (recommended for daily use)
./sync-upstream-auto.sh

# Interactive synchronization (more control)
./sync-upstream.sh

# Check available updates
git fetch upstream && git log --oneline HEAD..upstream/master
```

### ❌ **NEVER Use These Commands (You would lose your changes)**

```bash
# ❌ DANGEROUS - Takes you to upstream only WITHOUT your improvements
git checkout upstream/master
git reset --hard upstream/master
git pull upstream master  # Without proper merge
```

## 📋 Interactive Script Options

1. **Merge** - Preserves complete history
2. **Rebase** - Cleaner history  
3. **Automatic** - Detects the best strategy

## 🤖 Automation

- **GitHub Action**: Runs daily at 2:00 AM UTC
- **Manual execution**: From GitHub Actions tab
- **Automatic script**: `./sync-upstream-auto.sh`

## ⚡ Emergency Commands

```bash
git merge --abort              # Abort problematic merge
git stash pop                  # Restore saved changes
git status                     # View current status
git remote -v                  # Verify configured remotes
```

## 📖 Complete Documentation

See `FORK-SYNC-GUIDE.md` for detailed documentation with examples and troubleshooting.

---

**Upstream**: [AymanLyesri/ArchEclipse](https://github.com/AymanLyesri/ArchEclipse)  
**Your Fork**: [mrvictor22/ArchEclipse](https://github.com/mrvictor22/ArchEclipse)
