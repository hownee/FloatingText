#!/bin/bash
cd "$(dirname "$0")"

echo "Building FloatingText..."
swift build -c release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "To run: ./.build/release/FloatingText"
    echo ""
    echo "Shortcuts (requires Accessibility permissions):"
    echo "  Ctrl+Option+Right  →  Next text"
    echo "  Ctrl+Option+Left   →  Previous text"
    echo "  Ctrl+Option+Q      →  Quit"
    echo ""
    echo "Edit demo_texts.txt to change the displayed texts."
else
    echo "❌ Build failed"
    exit 1
fi
