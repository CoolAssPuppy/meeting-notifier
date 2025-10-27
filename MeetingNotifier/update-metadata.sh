#!/bin/bash

# update-metadata.sh - Update App Store metadata for MeetingNotifier
# Location: MeetingNotifier/update-metadata.sh
#
# Helper script for updating App Store descriptions, screenshots, and metadata

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   MeetingNotifier Metadata Manager${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Install dependencies if needed
if [ ! -f "Gemfile.lock" ]; then
    echo -e "${YELLOW}📦 Installing dependencies first...${NC}"
    bundle install
    echo ""
fi

echo -e "${BLUE}Select action:${NC}"
echo -e "${GREEN}1)${NC} Download current metadata from App Store Connect"
echo -e "${YELLOW}2)${NC} Upload updated metadata to App Store Connect"
echo ""
read -p "Choose action (1-2): " -n 1 -r ACTION
echo ""
echo ""

case $ACTION in
    1)
        echo -e "${GREEN}📥 Downloading metadata...${NC}"
        echo ""
        bundle exec fastlane download_metadata
        echo ""
        echo -e "${GREEN}✅ Metadata downloaded to ./fastlane/metadata${NC}"
        echo -e "${BLUE}   Edit the files and run option 2 to upload${NC}"
        ;;
    2)
        echo -e "${YELLOW}📤 Uploading metadata...${NC}"
        echo ""
        bundle exec fastlane upload_metadata
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
exit 0
