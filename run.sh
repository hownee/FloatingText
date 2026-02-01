#!/bin/bash
cd "$(dirname "$0")"

# Build if needed
if [ ! -f .build/release/FloatingText ]; then
    ./build.sh
fi

echo "Starting FloatingText..."
echo "Press Ctrl+Option+Q to quit"
echo ""

# Run from the project directory so it finds demo_texts.txt
./.build/release/FloatingText
