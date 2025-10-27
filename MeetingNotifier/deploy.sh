#!/bin/bash

# deploy.sh - Master deployment script for MeetingNotifier
# Location: MeetingNotifier/deploy.sh
#
# This script handles deploying MeetingNotifier to TestFlight or App Store
# It can be run from anywhere in the repository

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Find the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Print header
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   MeetingNotifier Deployment Script${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📁 Project Root:${NC} $PROJECT_ROOT"
echo -e "${BLUE}📂 Current Directory:${NC} $(pwd)"
echo ""

# Change to project root
cd "$PROJECT_ROOT" || exit 1

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check for Ruby
if ! command -v ruby &> /dev/null; then
    echo -e "${RED}❌ Ruby not found. Please install Ruby.${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Ruby found: $(ruby --version | cut -d' ' -f2)"

# Check for Bundler
if ! command -v bundle &> /dev/null; then
    echo -e "${RED}❌ Bundler not found. Installing...${NC}"
    gem install bundler
fi
echo -e "${GREEN}✓${NC} Bundler found"

# Check for .env file
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo -e "${YELLOW}   Please copy .env.default to .env and fill in your values:${NC}"
    echo -e "${CYAN}   cp .env.default .env${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Environment file found"

# Install dependencies if needed
if [ ! -f "Gemfile.lock" ] || [ "Gemfile" -nt "Gemfile.lock" ]; then
    echo -e "${YELLOW}📦 Installing Ruby dependencies...${NC}"
    bundle install
fi

# Check git status for production releases
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$REPO_ROOT" ]; then
    cd "$REPO_ROOT" || exit 1
    if [[ -n $(git status -s) ]]; then
        echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
        git status -s
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Deployment cancelled${NC}"
            exit 1
        fi
    fi
    cd "$PROJECT_ROOT" || exit 1
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   Select Deployment Type${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}1)${NC} TestFlight (Beta) - Fast, no review needed"
echo -e "${MAGENTA}2)${NC} App Store (Production) - Requires review"
echo -e "${YELLOW}3)${NC} Run Tests Only"
echo -e "${BLUE}4)${NC} Update Metadata Only"
echo ""
read -p "Choose deployment type (1-4): " -n 1 -r DEPLOY_TYPE
echo ""
echo ""

case $DEPLOY_TYPE in
    1)
        echo -e "${GREEN}🚀 Deploying to TestFlight...${NC}"
        echo ""
        bundle exec fastlane beta
        ;;
    2)
        echo -e "${MAGENTA}🚀 Preparing App Store release...${NC}"
        echo ""

        # Ask for version bump
        echo -e "${CYAN}Select version bump type:${NC}"
        echo -e "${GREEN}1)${NC} Patch (1.0.0 -> 1.0.1) - Bug fixes"
        echo -e "${YELLOW}2)${NC} Minor (1.0.0 -> 1.1.0) - New features"
        echo -e "${MAGENTA}3)${NC} Major (1.0.0 -> 2.0.0) - Breaking changes"
        echo -e "${BLUE}4)${NC} Skip version bump"
        echo ""
        read -p "Choose bump type (1-4): " -n 1 -r BUMP_TYPE
        echo ""

        case $BUMP_TYPE in
            1) bundle exec fastlane bump_patch ;;
            2) bundle exec fastlane bump_minor ;;
            3) bundle exec fastlane bump_major ;;
            4) echo -e "${YELLOW}Skipping version bump${NC}" ;;
            *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
        esac

        echo ""
        bundle exec fastlane release
        ;;
    3)
        echo -e "${YELLOW}🧪 Running tests...${NC}"
        echo ""
        bundle exec fastlane test
        ;;
    4)
        echo -e "${BLUE}📝 Updating App Store metadata...${NC}"
        echo ""
        bundle exec fastlane upload_metadata
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

# Print completion message
EXIT_CODE=$?
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"

    case $DEPLOY_TYPE in
        1)
            echo -e "  ${CYAN}•${NC} TestFlight build will be available in ~10 minutes"
            echo -e "  ${CYAN}•${NC} Check App Store Connect for processing status"
            echo -e "  ${CYAN}•${NC} Internal testers will be notified automatically"
            ;;
        2)
            echo -e "  ${CYAN}•${NC} Go to App Store Connect to submit for review"
            echo -e "  ${CYAN}•${NC} Review typically takes 1-3 days"
            echo -e "  ${CYAN}•${NC} Update release notes and screenshots if needed"
            ;;
    esac
else
    echo -e "${RED}❌ Deployment failed${NC}"
    echo -e "${YELLOW}Check the error messages above for details${NC}"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

exit $EXIT_CODE
