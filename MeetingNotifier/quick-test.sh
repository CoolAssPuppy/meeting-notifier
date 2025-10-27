#!/bin/bash

# quick-test.sh - Quick test runner for MeetingNotifier
# Location: MeetingNotifier/quick-test.sh
#
# Runs all tests quickly for local development verification

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   MeetingNotifier Quick Test${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🧪 Running tests...${NC}"
echo ""

# Install dependencies if needed
if [ ! -f "Gemfile.lock" ]; then
    echo -e "${YELLOW}📦 Installing dependencies first...${NC}"
    bundle install
    echo ""
fi

# Run tests
bundle exec fastlane test

EXIT_CODE=$?
echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Tests failed${NC}"
fi
echo ""

exit $EXIT_CODE
