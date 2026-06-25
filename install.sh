#!/bin/bash
# Nexus - Linux Server Manager
# Installer script

set -e

REPO_URL="https://raw.githubusercontent.com/parsa8585/nexus/main"
INSTALL_PATH="/usr/local/bin/nexus"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${CYAN}  ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗${NC}"
echo -e "${CYAN}  ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝${NC}"
echo -e "${CYAN}  ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗${NC}"
echo -e "${CYAN}  ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║${NC}"
echo -e "${CYAN}  ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║${NC}"
echo -e "${CYAN}  ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝${NC}"
echo ""
echo -e "  ${YELLOW}Linux Server Manager — Installer${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "  ${YELLOW}[!] Not running as root. Trying with sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

# Check curl
if ! command -v curl &>/dev/null; then
    echo -e "  ${RED}[ERR] curl is required. Install it first:${NC}"
    echo -e "        apt install curl   OR   yum install curl"
    exit 1
fi

echo -e "  ${CYAN}[*] Downloading Nexus...${NC}"
curl -fsSL "${REPO_URL}/nexus.sh" -o "$INSTALL_PATH"

chmod +x "$INSTALL_PATH"

echo -e "  ${GREEN}[OK] Nexus installed to: ${INSTALL_PATH}${NC}"
echo ""
echo -e "  Run it anytime with:  ${YELLOW}nexus${NC}"
echo ""

# Ask to run now
read -p "  Run Nexus now? [Y/n]: " -n 1 -r RUN_NOW
echo ""
if [[ "$RUN_NOW" =~ ^[Yy]$ ]] || [ -z "$RUN_NOW" ]; then
    exec bash "$INSTALL_PATH"
fi
