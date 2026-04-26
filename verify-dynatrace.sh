#!/bin/bash

# Verify Dynatrace credentials and API access
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Dynatrace Configuration Verification                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

# Load .env
if [ ! -f ".env" ]; then
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi

export $(cat .env | grep -v '^#' | xargs)

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Environment ID: ${GREEN}${DT_ENVIRONMENT_ID}${NC}"
echo -e "  Connection Point: ${GREEN}${DT_CONNECTION_POINT}${NC}"
echo -e "  API Token: ${GREEN}${DT_API_TOKEN:0:20}...${NC}\n"

# Test 1: Check if Dynatrace endpoint is reachable
echo -e "${BLUE}Test 1: Checking Dynatrace endpoint reachability...${NC}"
if curl -s -o /dev/null -w "%{http_code}" "${DT_CONNECTION_POINT}" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Dynatrace endpoint is reachable${NC}\n"
else
    echo -e "${RED}✗ Cannot reach Dynatrace endpoint${NC}"
    echo -e "${YELLOW}Check your DT_CONNECTION_POINT in .env${NC}\n"
fi

# Test 2: Test API token validity
echo -e "${BLUE}Test 2: Testing API token validity...${NC}"
API_TEST=$(curl -s -w "\n%{http_code}" -H "Authorization: Api-Token ${DT_API_TOKEN}" \
    "${DT_CONNECTION_POINT}/api/v2/entities" || echo "000")

HTTP_CODE=$(echo "$API_TEST" | tail -n 1)
RESPONSE=$(echo "$API_TEST" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ API token is valid and working${NC}\n"
elif [ "$HTTP_CODE" == "401" ]; then
    echo -e "${RED}✗ API token is INVALID or EXPIRED${NC}"
    echo -e "${YELLOW}Please regenerate your token in Dynatrace${NC}\n"
    exit 1
elif [ "$HTTP_CODE" == "403" ]; then
    echo -e "${YELLOW}⚠ API token is valid but may lack permissions${NC}\n"
else
    echo -e "${RED}✗ Unexpected response: HTTP ${HTTP_CODE}${NC}"
    echo -e "${YELLOW}Response: ${RESPONSE}${NC}\n"
fi

# Test 3: Test OneAgent download endpoint
echo -e "${BLUE}Test 3: Testing OneAgent installer download...${NC}"
DOWNLOAD_URL="${DT_CONNECTION_POINT}/api/v1/deployment/installer/agent/unix/default/latest?arch=x86"
echo -e "${YELLOW}URL: ${DOWNLOAD_URL}${NC}"

DOWNLOAD_TEST=$(curl -s -L -w "\n%{http_code}" \
    -H "Authorization: Api-Token ${DT_API_TOKEN}" \
    "${DOWNLOAD_URL}" -o /tmp/oneagent-test.sh || echo "000")

DL_HTTP_CODE=$(echo "$DOWNLOAD_TEST" | tail -n 1)

if [ "$DL_HTTP_CODE" == "200" ]; then
    if [ -f /tmp/oneagent-test.sh ] && [ -s /tmp/oneagent-test.sh ]; then
        FILE_SIZE=$(ls -lh /tmp/oneagent-test.sh | awk '{print $5}')
        echo -e "${GREEN}✓ OneAgent installer downloaded successfully (${FILE_SIZE})${NC}"
        rm -f /tmp/oneagent-test.sh
        echo -e "${GREEN}\n╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ALL TESTS PASSED - Ready to build with Dynatrace!    ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"
        echo -e "${BLUE}Next step: Run ./test-dynatrace-locally.sh${NC}\n"
    else
        echo -e "${RED}✗ File downloaded but is empty${NC}\n"
        rm -f /tmp/oneagent-test.sh
        exit 1
    fi
elif [ "$DL_HTTP_CODE" == "403" ]; then
    echo -e "${RED}✗ 403 Forbidden - Token lacks InstallerDownload permission${NC}"
    echo -e "${YELLOW}\nTo fix this:${NC}"
    echo -e "  1. Go to: ${DT_CONNECTION_POINT}"
    echo -e "  2. Navigate to: Settings → Access tokens"
    echo -e "  3. Create a new token with these scopes:"
    echo -e "     ${GREEN}✓ InstallerDownload${NC} (or 'PaaS integration - Installer download')"
    echo -e "     ${GREEN}✓ DataExport${NC} (optional)"
    echo -e "  4. Update DT_API_TOKEN in .env with the new token"
    echo -e "  5. Run this script again\n"
    rm -f /tmp/oneagent-test.sh
    exit 1
elif [ "$DL_HTTP_CODE" == "401" ]; then
    echo -e "${RED}✗ 401 Unauthorized - Invalid API token${NC}\n"
    rm -f /tmp/oneagent-test.sh
    exit 1
else
    echo -e "${RED}✗ Unexpected response: HTTP ${DL_HTTP_CODE}${NC}"
    RESPONSE_CONTENT=$(head -n 5 /tmp/oneagent-test.sh 2>/dev/null || echo "No content")
    echo -e "${YELLOW}Response: ${RESPONSE_CONTENT}${NC}\n"
    rm -f /tmp/oneagent-test.sh
    exit 1
fi
