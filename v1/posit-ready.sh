#!/bin/bash

# Posit Team Environment Readiness Check

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}--- Posit Team Readiness Check ---${NC}"
echo "This script checks system requirements for Workbench, Connect, and Package Manager."

# Save the list of systemd unit files to a variable to avoid running systemctl multiple times
UNIT_FILES=$(systemctl list-unit-files)

# Sam Cofers checks 
echo -e "\n${BLUE}--- System Infrastructure ---${NC}"
echo -e "Hostname: $(hostname)"
OS_INFO=$(grep -E '^(PRETTY_NAME)=' /etc/os-release | cut -d= -f2 | tr -d '"')
echo -e "OS: $OS_INFO"
echo -e "CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | sed 's/^ *//') ($(nproc) cores)"
echo -e "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"

echo -e ${BLUE}"Hostname: "${NC}`hostname` && \
echo -e -n ${BLUE}"OS Version: "${NC} && \
echo -e "$(grep -E '^(PRETTY_NAME)=' /etc/os-release | cut -d= -f2 | tr -d '"')" && \
echo -e ${BLUE}"IP Addresses: "${NC} && ip -o -4 addr show | awk -v BLUE="$BLUE" -v NC="$NC" '!/127.0.0.1/ {print "   " BLUE $2 NC ": " $4}'  && \
echo -e ${BLUE}"Memory Utilization:${NC} $(free -h | awk '/^Mem:/ {print $3 "/" $2}')" && \
echo -e ${BLUE}"CPU:${NC} $(lscpu | grep 'Model name' | awk -F: '{print $2}' | sed 's/^ *//')" && \
echo -e ${BLUE}"   CPU Cores:"${NC} $(nproc) && \
echo -e ${BLUE}"Mounted Directories and Storage:"${NC} && \
df -h | head -n 1 | GREP_COLORS='mt=01;32' grep -E --color 'K|M|G|T|Avail|Size|Filesystem|Use%|Used|Mounted on' && \
df -h | tail -n +2 | sort -k6 | GREP_COLORS='mt=01;32' grep -E --color 'K|M|G|T|Avail|Size|Filesystem|Use%|Used|Mounted on' && \

# Optimized Storage & Permissions Check
echo -e "\n${BLUE}--- Data Directory Permissions & Mount Options ---${NC}"

# Define the critical paths for Posit Products
DIRS=("/var/lib/rstudio-server" "/var/lib/rstudio-connect" "/var/lib/rstudio-pm" "/opt/python" "/opt/R")

printf "%-30s %-10s %-10s %-15s %-20s\n" "Directory" "Owner" "Perms" "Size/Used" "Mount Options"
echo "------------------------------------------------------------------------------------------------------------"

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Get ownership and octal permissions
        owner=$(stat -c '%U:%G' "$dir")
        perms=$(stat -c '%a' "$dir")
        
        # Get disk usage for the specific mount
        usage=$(df -h "$dir" | tail -1 | awk '{print $3"/"$2 " (" $5 ")"}')
        
        # Get mount options (Check for noexec, nosuid, nodev)
        mount_opts=$(findmnt -n -o OPTIONS -T "$dir")
        
        # Highlight risky mount options
        if [[ "$mount_opts" =~ "noexec" ]]; then
            opts_display="${RED}$mount_opts (BLOCKS EXECUTION)${NC}"
        else
            opts_display="${GREEN}$mount_opts${NC}"
        fi

        printf "%-30s %-10s %-10s %-15s %-20b\n" "$dir" "$owner" "$perms" "$usage" "$opts_display"
    else
        printf "%-30s %-40s\n" "$dir" "${YELLOW}Not Created Yet${NC}"
    fi
done

# RStudio Services
echo -e ${BLUE}"Checking RStudio Services:${NC}" && \
for svc in rstudio-server rstudio-launcher rstudio-connect rstudio-pm; do
    if echo "$UNIT_FILES" | grep -q "^$svc.service"; then
        status=$(systemctl is-active $svc 2>/dev/null)
        if [[ "$status" == "active" ]]; then
            echo -e "   ${BLUE}$svc:${GREEN} Installed${NC}"
        else
            echo -e "   ${BLUE}$svc:${YELLOW} Installed but Inactive${NC}"
        fi
    else
        echo -e "   ${BLUE}$svc:${RED} Not Installed${NC}"
    fi
done && \

# List installed R versions in /opt/R (only versions starting with 3 or 4)
echo -e ${BLUE}"Checking Installed R Versions (/opt/R):"${NC} && \
if [[ -d "/opt/R" ]]; then
    R_VERSIONS=$(ls -r /opt/R | grep -E '^[34]' | tr '\n' ',' | sed 's/,$//')
    if [[ -z "$R_VERSIONS" ]]; then
        echo -e "   ${RED}No Posit R versions installed${NC}"
    else
        echo -e "   ${GREEN}$R_VERSIONS${NC}"
    fi
else
    echo -e "   ${RED}No Posit R versions installed${NC}"
fi && \

# List installed Python versions in /opt/python (only versions starting with 3 or 4)
echo -e ${BLUE}"Checking Installed Python Versions (/opt/python):"${NC} && \
if [[ -d "/opt/python" ]]; then
    PYTHON_VERSIONS=$(ls -r /opt/python | grep -E '^[34]' | tr '\n' ',' | sed 's/,$//')
    if [[ -z "$PYTHON_VERSIONS" ]]; then
        echo -e "   ${RED}No Posit Python versions installed${NC}"
    else
        echo -e "   ${GREEN}$PYTHON_VERSIONS${NC}"
    fi
else
    echo -e "   ${RED}No Posit Python versions installed${NC}"
fi && \

# Check Internet Access
echo -e ${BLUE}"Checking Internet Access (google.com):"${NC} && \
if ping -c 1 -W 2 google.com &> /dev/null; then
    echo -e "   ${BLUE}Internet:${GREEN} Available${NC}"
else
    echo -e "   ${BLUE}Internet:${RED} Not Available${NC}"
fi && \

# Check Proxy Settings
echo -e ${BLUE}"Checking Proxy Settings:"${NC} && \
echo -e "   HTTP Proxy: ${NC}$(echo ${HTTP_PROXY:-None})" && \
echo -e "   HTTPS Proxy: ${NC}$(echo ${HTTPS_PROXY:-None})" && \

# Security Services Check
echo -e ${BLUE}"Checking Security Services:${NC}" && \
for sec_svc in iptables nftables firewalld; do
    if echo "$UNIT_FILES" | grep -q "^$sec_svc.service"; then
        status=$(systemctl is-active $sec_svc 2>/dev/null)
        if [[ "$status" == "active" ]]; then
            echo -e "   ${BLUE}$sec_svc:${GREEN} Installed & Active${NC}"
        else
            echo -e "   ${BLUE}$sec_svc:${YELLOW} Installed but Inactive${NC}"
        fi
    else
        echo -e "   ${BLUE}$sec_svc:${RED} Not Installed${NC}"
    fi
done && \

# SELinux/AppArmor
if command -v getenforce >/dev/null 2>&1; then
    MODE=$(getenforce)
    [[ "$MODE" == "Enforcing" ]] && echo -e "${RED}[WARN]${NC} SELinux: Enforcing (Requires custom policies)." || echo -e "${GREEN}[PASS]${NC} SELinux: $MODE"
elif command -v aa-status >/dev/null 2>&1; then
    echo -e "${GREEN}[INFO]${NC} AppArmor is active."
fi

# Check SELinux Status
if command -v sestatus &> /dev/null; then
    SELINUX_STATUS=$(sestatus | awk '/SELinux status:/ {print $3}')
    if [[ "$SELINUX_STATUS" == "enabled" ]]; then
        echo -e "   ${BLUE}SELinux:${GREEN} Enabled${NC}"
    else
        echo -e "   ${BLUE}SELinux:${RED} Disabled${NC}"
    fi
else
    echo -e "   ${BLUE}SELinux:${RED} Not Installed${NC}"
fi && \

# Check AppArmor Status
if command -v aa-status &> /dev/null; then
    APPARMOR_STATUS=$(aa-status --enforce | grep -c "enforce mode")
    if [[ "$APPARMOR_STATUS" -gt 0 ]]; then
        echo -e "   ${BLUE}AppArmor:${GREEN} Enabled${NC}"
    else
        echo -e "   ${BLUE}AppArmor:${RED} Disabled${NC}"
    fi
else
    echo -e "   ${BLUE}AppArmor:${RED} Not Installed${NC}"
fi

# Check for Sudo/Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[FAIL]${NC} This script must be run with sudo/root privileges."
   exit 1
else
   echo -e "${GREEN}[PASS]${NC} Running with root/sudo privileges."
fi

# OS Verification
OS_NAME=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_VER=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
echo -e "${YELLOW}[INFO]${NC} Operating System: $OS_NAME $OS_VER"

# OS and Kernel Verification
OS_NAME=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_VER=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
echo -e "${YELLOW}[INFO]${NC} OS Detected: $OS_NAME $OS_VER"

# 2. Infrastructure & Performance
echo -e "\n${BLUE}--- System Infrastructure ---${NC}"
echo -e "Hostname: $(hostname)"
OS_INFO=$(grep -E '^(PRETTY_NAME)=' /etc/os-release | cut -d= -f2 | tr -d '"')
echo -e "OS: $OS_INFO"
echo -e "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"

# Security & Hardening (SELinux/Umask)
echo -e "\n${YELLOW}--- Security Settings ---${NC}"
if command -v sestatus >/dev/null 2>&1; then
    SELINUX_MODE=$(getenforce)
    [[ "$SELINUX_MODE" == "Enforcing" ]] && echo -e "${RED}[WARN]${NC} SELinux is Enforcing." || echo -e "${GREEN}[PASS]${NC} SELinux: $SELINUX_MODE"
fi

CURRENT_UMASK=$(umask)
[[ "$CURRENT_UMASK" == "0077" ]] && echo -e "${RED}[FAIL]${NC} Umask 0077 detected (Access issues)." || echo -e "${GREEN}[PASS]${NC} Umask: $CURRENT_UMASK"

# Storage & /tmp Execution
if mount | grep -q "on /tmp .*noexec"; then
    echo -e "${RED}[FAIL]${NC} /tmp has 'noexec' set. Posit installers will fail."
else
    echo -e "${GREEN}[PASS]${NC} /tmp allows execution."
fi

# SELinux Status
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

# Umask Check
CURRENT_UMASK=$(umask)
if [[ "$CURRENT_UMASK" == "0077" ]]; then
    echo -e "${RED}[FAIL]${NC} Umask is 0077. This will cause permission issues. Recommend 0022."
else
    echo -e "${GREEN}[PASS]${NC} Umask is $CURRENT_UMASK."
fi

# Swap space
echo -n "Checking Swap Status... "
swap_total=$(free | grep Swap | awk '{print $2}')
if [ "$swap_total" -eq 0 ]; then
    echo -e "${YELLOW}[WARN]${NC} No Swap space configured. Server may crash if RAM is exhausted."
else
    echo -e "${GREEN}[PASS]${NC} Swap is available ($swap_total KB)."
fi

# Dependency Check (NFS & Database Tools)
echo -e "\n${YELLOW}--- System Dependencies ---${NC}"
for pkg in nfs-utils psql; do
    if command -v $pkg >/dev/null 2>&1 || rpm -q $pkg >/dev/null 2>&1 || dpkg -s $pkg >/dev/null 2>&1; then
        echo -e "${GREEN}[FOUND]${NC} $pkg is installed."
    else
        echo -e "${YELLOW}[MISSING]${NC} $pkg not found. (Required for NFS/Postgres validation)."
    fi
done

# Database Connectivity Check (Interactive)
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

# /tmp Execution Check
if mount | grep -q "on /tmp .*noexec"; then
    echo -e "${RED}[FAIL]${NC} /tmp is mounted with noexec. Posit installers require execution in /tmp."
else
    echo -e "${GREEN}[PASS]${NC} /tmp allows execution."
fi

# Placeholder for torage checks
#  file locking, ACL’s, IO ping for performance, case sensitivity on back end storage, etc script - work with Sam C

# Check for Languages (R, Python, Quarto)
echo -e "\n${YELLOW}--- Language Runtime Checks ---${NC}"
for lang in "/opt/R" "/opt/python" "/opt/quarto"; do
    if [ -d "$lang" ]; then
        echo -e "${GREEN}[FOUND]${NC} $lang directory exists."
        ls -1d $lang/* 2>/dev/null | sed 's/^/  - /'
    else
        echo -e "${YELLOW}[MISSING]${NC} $lang not found in /opt (standard location)."
    fi
done

# Language Runtimes
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

# Network Port Availability (Basic)
echo -e "\n${YELLOW}--- Network Port Check (Internal) ---${NC}"
for port in 8787 3939 4242 5559 443; do
    if ss -tuln | grep -q ":$port "; then
        echo -e "${RED}[WARN]${NC} Port $port is already in use."
    else
        echo -e "${GREEN}[OPEN]${NC} Port $port is available for use."
    fi
done





# End
echo -e "\n${YELLOW}--- End of Readiness Check ---${NC}"
echo "Please share this output with your Posit contact if you have questions."


