#!/bin/bash

# Script to copy Long Covid plan files to AIO Launcher scripts directory
# This needs to be run on the Android device or via ADB

SOURCE_DIR="/sdcard/Documents/pdyxs/Long Covid/plans"
DEST_DIR="/sdcard/Android/data/ru.execbit.aiolauncher/files/scripts"

echo "Copying Long Covid plan files to AIO Launcher directory..."

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy decision criteria
if [ -f "$SOURCE_DIR/decision_criteria.md" ]; then
    cp "$SOURCE_DIR/decision_criteria.md" "$DEST_DIR/"
    echo "✓ Copied decision_criteria.md"
else
    echo "✗ decision_criteria.md not found"
fi

# Copy day files
for day in monday tuesday wednesday thursday friday weekend; do
    if [ -f "$SOURCE_DIR/days/$day.md" ]; then
        cp "$SOURCE_DIR/days/$day.md" "$DEST_DIR/"
        echo "✓ Copied $day.md"
    else
        echo "✗ $day.md not found"
    fi
done

# Copy tracking file if it exists (optional)
if [ -f "$SOURCE_DIR/tracking.md" ]; then
    cp "$SOURCE_DIR/tracking.md" "$DEST_DIR/"
    echo "✓ Copied existing tracking.md"
else
    echo "ℹ No existing tracking.md (will be created by widget)"
fi

echo ""
echo "File copy complete!"
echo "AIO Launcher widget should now be able to access plan data."