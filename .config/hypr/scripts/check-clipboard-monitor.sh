#!/bin/bash
# Clipboard Monitor Health Check
# Verifies that only ONE instance is running

echo "🔍 Checking Clipboard Monitor Status..."
echo ""

# Count running wl-paste clipboard processes
WL_COUNT=$(pgrep -fc "wl-paste.*clipboard" 2>/dev/null || echo "0")
echo "📊 wl-paste processes found: $WL_COUNT"

# List the processes
if [ "$WL_COUNT" -gt 0 ]; then
    echo ""
    echo "📋 Process list:"
    ps aux | grep -E "(wl-paste|clipboard)" | grep -v grep | grep -v "check-clipboard"
fi

# Check PID file
if [ -f "/tmp/clipboard-monitor.pid" ]; then
    PID=$(cat /tmp/clipboard-monitor.pid)
    echo ""
    echo "📄 PID file exists: $PID"
    if kill -0 "$PID" 2>/dev/null; then
        echo "✅ Process $PID is running"
    else
        echo "⚠️  Process $PID is NOT running (stale PID file)"
    fi
else
    echo ""
    echo "⚠️  No PID file found"
fi

# Check lock directory
if [ -d "/tmp/clipboard-monitor.lock.d" ]; then
    echo ""
    echo "🔒 Lock directory exists"
else
    echo ""
    echo "⚠️  No lock directory found"
fi

# Show recent startup logs
if [ -f "/tmp/clipboard-monitor-startup.log" ]; then
    echo ""
    echo "📜 Recent startup log (last 10 lines):"
    tail -10 /tmp/clipboard-monitor-startup.log
fi

# Show recent clipboard activity
if [ -f "/tmp/clip-count.log" ]; then
    echo ""
    echo "📝 Recent clipboard activity (last 10 lines):"
    tail -10 /tmp/clip-count.log
fi

# Final verdict
echo ""
echo "═══════════════════════════════════════"
if [ "$WL_COUNT" -eq 1 ]; then
    echo "✅ STATUS: HEALTHY - Exactly 1 process running"
elif [ "$WL_COUNT" -eq 0 ]; then
    echo "❌ STATUS: NOT RUNNING - No processes found"
    echo "   Run: $HOME/.config/hypr/scripts/start-clipboard-monitor.sh"
else
    echo "⚠️  STATUS: UNHEALTHY - Multiple processes detected ($WL_COUNT)"
    echo "   This will cause duplicate notifications!"
    echo "   Fix: Run the start script again to clean up"
fi
echo "═══════════════════════════════════════"
