#!/bin/bash
# Test script to debug clipboard image issues

echo "=== Clipboard Image Debug Test ==="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Test 1: Copy an image to clipboard
TEST_IMAGE="/home/alphonse/Pictures/Screenshots/latest.png"
if [ -f "$TEST_IMAGE" ]; then
    echo "Test image found: $TEST_IMAGE"
    echo "Size: $(du -h "$TEST_IMAGE" | cut -f1)"

    # Copy to clipboard
    echo "Copying to clipboard..."
    wl-copy -t image/png < "$TEST_IMAGE"

    # Check clipboard types
    echo ""
    echo "Clipboard types available:"
    wl-paste --list-types

    # Test saving from clipboard
    echo ""
    echo "Testing save from clipboard..."
    TEST_OUTPUT="/tmp/test_clipboard_$(date +%s).png"

    # Try different methods
    echo "Method 1: Direct wl-paste"
    if timeout 3s wl-paste --type image/png > "${TEST_OUTPUT}_1.png" 2>/dev/null; then
        echo "  Success! Size: $(stat -c%s "${TEST_OUTPUT}_1.png") bytes"
    else
        echo "  Failed!"
    fi

    echo "Method 2: With /dev/null redirect (like clipboard-monitor.sh)"
    if timeout 3s wl-paste --type image/png </dev/null >"${TEST_OUTPUT}_2.png" 2>/dev/null; then
        echo "  Success! Size: $(stat -c%s "${TEST_OUTPUT}_2.png") bytes"
    else
        echo "  Failed!"
    fi

    echo "Method 3: Without timeout"
    if wl-paste --type image/png > "${TEST_OUTPUT}_3.png" 2>/dev/null; then
        echo "  Success! Size: $(stat -c%s "${TEST_OUTPUT}_3.png") bytes"
    else
        echo "  Failed!"
    fi

    # Check saved files
    echo ""
    echo "Saved test files:"
    ls -lah "${TEST_OUTPUT}"*.png 2>/dev/null || echo "No files saved"

else
    echo "Error: No test image found at $TEST_IMAGE"
    echo "Please take a screenshot first"
fi

echo ""
echo "=== End of test ==="