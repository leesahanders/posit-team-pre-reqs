#!/bin/bash

# Posit Team Environment Readiness Check

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}--- Posit Team Readiness Check ---${NC}"
echo "This script validates system requirements for Workbench, Connect, and Package Manager."

# 1. Check for Sudo/Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[FAIL]${NC} This script must be run with sudo/root privileges."
   exit 1
else
   echo -e "${GREEN}[PASS]${NC} Running with root/sudo privileges."
fi

# 2. OS Verification
OS_NAME=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_VER=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
echo -e "${YELLOW}[INFO]${NC} Operating System: $OS_NAME $OS_VER"

# 2. OS and Kernel Verification
OS_NAME=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_VER=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
echo -e "${YELLOW}[INFO]${NC} OS Detected: $OS_NAME $OS_VER"

# 3. Security & Hardening (SELinux/Umask)
echo -e "\n${YELLOW}--- Security Settings ---${NC}"
if command -v sestatus >/dev/null 2>&1; then
    SELINUX_MODE=$(getenforce)
    [[ "$SELINUX_MODE" == "Enforcing" ]] && echo -e "${RED}[WARN]${NC} SELinux is Enforcing." || echo -e "${GREEN}[PASS]${NC} SELinux: $SELINUX_MODE"
fi

CURRENT_UMASK=$(umask)
[[ "$CURRENT_UMASK" == "0077" ]] && echo -e "${RED}[FAIL]${NC} Umask 0077 detected (Access issues)." || echo -e "${GREEN}[PASS]${NC} Umask: $CURRENT_UMASK"

# 4. Storage & /tmp Execution
if mount | grep -q "on /tmp .*noexec"; then
    echo -e "${RED}[FAIL]${NC} /tmp has 'noexec' set. Posit installers will fail."
else
    echo -e "${GREEN}[PASS]${NC} /tmp allows execution."
fi

# 3. SELinux Status
if command -v sestatus >/dev/null 2>&1; then
    SELINUX_MODE=$(getenforce)
    if [[ "$SELINUX_MODE" == "Enforcing" ]]; then
        echo -e "${RED}[WARN]${NC} SELinux is Enforcing. This may block installation steps."
    else
        echo -e "${GREEN}[PASS]${NC} SELinux mode: $SELINUX_MODE"
    fi
else
    echo -e "${GREEN}[PASS]${NC} SELinux not detected (common on Ubuntu/Debian)."
fi

# 4. Umask Check
CURRENT_UMASK=$(umask)
if [[ "$CURRENT_UMASK" == "0077" ]]; then
    echo -e "${RED}[FAIL]${NC} Umask is 0077. This will cause permission issues. Recommend 0022."
else
    echo -e "${GREEN}[PASS]${NC} Umask is $CURRENT_UMASK."
fi

# 5. Dependency Check (NFS & Database Tools)
echo -e "\n${YELLOW}--- System Dependencies ---${NC}"
for pkg in nfs-utils psql; do
    if command -v $pkg >/dev/null 2>&1 || rpm -q $pkg >/dev/null 2>&1 || dpkg -s $pkg >/dev/null 2>&1; then
        echo -e "${GREEN}[FOUND]${NC} $pkg is installed."
    else
        echo -e "${YELLOW}[MISSING]${NC} $pkg not found. (Required for NFS/Postgres validation)."
    fi
done

# 6. Database Connectivity Check (Interactive)
echo -e "\n${YELLOW}--- Database Connectivity Test ---${NC}"
read -p "Test Postgres connection? (y/n): " do_db
if [[ "$do_db" =~ ^[Yy]$ ]]; then
    read -p "Enter Postgres Host: " DB_HOST
    read -p "Enter Postgres User: " DB_USER
    read -p "Enter Database Name: " DB_NAME
    
    echo "Testing connection (will prompt for password)..."
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\conninfo'
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[PASS]${NC} Database connection successful."
    else
        echo -e "${RED}[FAIL]${NC} Database connection failed."
    fi
fi

# 5. /tmp Execution Check
if mount | grep -q "on /tmp .*noexec"; then
    echo -e "${RED}[FAIL]${NC} /tmp is mounted with noexec. Posit installers require execution in /tmp."
else
    echo -e "${GREEN}[PASS]${NC} /tmp allows execution."
fi

# 6. Check for Languages (R, Python, Quarto)
echo -e "\n${YELLOW}--- Language Runtime Checks ---${NC}"
for lang in "/opt/R" "/opt/python" "/opt/quarto"; do
    if [ -d "$lang" ]; then
        echo -e "${GREEN}[FOUND]${NC} $lang directory exists."
        ls -1d $lang/* 2>/dev/null | sed 's/^/  - /'
    else
        echo -e "${YELLOW}[MISSING]${NC} $lang not found in /opt (standard location)."
    fi
done

# 7. Language Runtimes
echo -e "\n${YELLOW}--- Language Runtimes (/opt/) ---${NC}"
for lang in "/opt/R" "/opt/python" "/opt/quarto"; do
    if [ -d "$lang" ]; then
        echo -e "${GREEN}[FOUND]${NC} $lang"
        ls -1d $lang/* 2>/dev/null | sed 's/^/  - /'
    else
        echo -e "${YELLOW}[MISSING]${NC} $lang"
    fi
done

echo -e "\n${YELLOW}--- Check Complete ---${NC}"

# 7. Network Port Availability (Basic)
echo -e "\n${YELLOW}--- Network Port Check (Internal) ---${NC}"
for port in 8787 3939 4242 5559 443; do
    if ss -tuln | grep -q ":$port "; then
        echo -e "${RED}[WARN]${NC} Port $port is already in use."
    else
        echo -e "${GREEN}[OPEN]${NC} Port $port is available for use."
    fi
done

echo -e "\n${YELLOW}--- End of Readiness Check ---${NC}"
echo "Please share this output with your Posit contact if you have questions."