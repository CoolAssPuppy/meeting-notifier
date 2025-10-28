#!/bin/bash

# Script to clean up old keychain entries for Meeting Notifier
# This is useful if the app previously used a different bundle identifier

SERVICE_NAME="com.strategicnerds.meetingnotifier"

echo "Cleaning up keychain entries for $SERVICE_NAME..."
echo "This will remove all stored OAuth tokens."
echo ""
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cancelled."
    exit 1
fi

# Find all keychain items for this service and delete them
security find-generic-password -s "$SERVICE_NAME" -a "" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Found keychain entries. Deleting..."
    # Delete all entries (this will prompt for each one)
    security delete-generic-password -s "$SERVICE_NAME" 2>/dev/null
    echo "Keychain entries deleted."
else
    echo "No keychain entries found for $SERVICE_NAME"
fi

echo ""
echo "Done! You will need to re-authenticate all your calendar accounts."
