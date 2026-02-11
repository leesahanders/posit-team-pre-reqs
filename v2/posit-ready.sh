#!/bin/bash

# Posit Team Environment Readiness Check

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}--- Posit Team Readiness Check ---${NC}"
echo "This script checks system pre-requirements for Workbench, Connect, and Package Manager."

# Root Check (Must be first)
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[FAIL]${NC} This script must be run with sudo/root privileges."
   exit 1
fi

# Save the list of systemd unit files to a variable to avoid running systemctl multiple times
UNIT_FILES=$(systemctl list-unit-files)

# System Info & Performance
echo -e "\n${YELLOW}--- System Infrastructure ---${NC}"
echo -e "${YELLOW}Hostname: ${NC}$(hostname)"
OS_INFO=$(grep -E '^(PRETTY_NAME)=' /etc/os-release | cut -d= -f2 | tr -d '"')
echo -e "${YELLOW}OS: ${NC}$OS_INFO" 
echo -e "${YELLOW}CPU:${NC} $(lscpu | grep 'Model name' | awk -F: '{print $2}' | sed 's/^ *//')" && \
echo -e ${BLUE}"   CPU Cores:"${NC} $(nproc) && \
echo -e "${YELLOW}RAM/Memory Utilization: ${NC}$(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo -e "${YELLOW}IP Addresses: "${NC} && ip -o -4 addr show | awk -v BLUE="$BLUE" -v NC="$NC" '!/127.0.0.1/ {print "   " BLUE $2 NC ": " $4}' 

# Posit Services
echo -e "\n${YELLOW}--- Checking Posit Services ---${NC}" && \
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
done && 

# Security & Hardening
echo -e "\n${YELLOW}--- Server Hardening ---${NC}"

# Check SELinux Status
if command -v sestatus &> /dev/null; then
    SELINUX_STATUS=$(sestatus | awk '/SELinux status:/ {print $3}')
    if [[ "$SELINUX_STATUS" == "enabled" ]]; then
        echo -e "   ${BLUE}SELinux:${RED} Enabled${NC}"
    else
        echo -e "   ${BLUE}SELinux:${BLUE} Disabled${NC}"
    fi
else
    echo -e "   ${BLUE}SELinux:${BLUE} Not Installed${NC}"
fi && \

# Check AppArmor Status
if command -v aa-status &> /dev/null; then
    APPARMOR_STATUS=$(aa-status --enforce | grep -c "enforce mode")
    if [[ "$APPARMOR_STATUS" -gt 0 ]]; then
        echo -e "   ${BLUE}AppArmor:${RED} Enabled${NC}"
    else
        echo -e "   ${BLUE}AppArmor:${BLUE} Disabled${NC}"
    fi
else
    echo -e "   ${BLUE}AppArmor:${BLUE} Not Installed${NC}"
fi

# Umask
CURRENT_UMASK=$(umask)
[[ "$CURRENT_UMASK" == "0077" ]] && echo -e "${RED}[FAIL]${NC} Umask 0077 detected (Access issues)." || echo -e "${GREEN}[PASS]${NC} Umask: $CURRENT_UMASK"

# Dependency Check (NFS & Database Tools)
echo -e "\n${YELLOW}--- System Dependencies ---${NC}"
for pkg in nfs-utils psql; do
    if command -v $pkg >/dev/null 2>&1 || rpm -q $pkg >/dev/null 2>&1 || dpkg -s $pkg >/dev/null 2>&1; then
        echo -e "${GREEN}[FOUND]${NC} $pkg is installed."
    else
        echo -e "${YELLOW}[MISSING]${NC} $pkg not found. (Required for NFS/Postgres validation)."
    fi
done

echo -e "\n${YELLOW}--- Data Directory Permissions & Mount Options ---${NC}"



# Define the critical paths for Posit Products
DIRS=("/etc/rstudio/" "/var/lib/" "/var/lib/rstudio-server" "/var/lib/rstudio-connect" "/var/lib/rstudio-pm" "/opt/python" "/opt/R")

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

#echo -e "Mounted Directories and Storage:"${NC} && \
#df -h | head -n 1 | GREP_COLORS='mt=01;32' grep -E --color 'K|M|G|T|Avail|Size|Filesystem|Use%|Used|Mounted on' && \
#df -h | tail -n +2 | sort -k6 | GREP_COLORS='mt=01;32' grep -E --color 'K|M|G|T|Avail|Size|Filesystem|Use%|Used|Mounted on' && \

# Storage & Filesystem Checks
echo -e "\n${YELLOW}--- Storage and Filesystem Checks ---${NC}"

# Todo make this interactive for storage location
check_dir="/var/lib/rstudio-server" # Change this to your intended data mount if different
mkdir -p "$check_dir" 2>/dev/null

# Exec Check
if mount | grep -qE "on (/tmp|/var/lib) .*noexec"; then
    echo -e "${RED}[FAIL]${NC} 'noexec' detected on /tmp or /var/lib. Execution blocked. Posit installers require execution. "
else
    echo -e "${GREEN}[PASS]${NC} Binary execution allowed on system mounts."
fi

# Case Sensitivity Check
touch "${check_dir}/POSIT_CASE_TEST"
if [ -f "${check_dir}/posit_case_test" ]; then
    echo -e "${RED}[FAIL]${NC} Filesystem is Case-Insensitive! (Standard for Windows/Mac, but breaks Posit on Linux)."
else
    echo -e "${GREEN}[PASS]${NC} Filesystem is Case-Sensitive."
fi
rm -f "${check_dir}/POSIT_CASE_TEST"

# File Locking Check (Critical for NFS)
if flock -x -n "${check_dir}/lockfile" -c "sleep 0.1" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} File locking (flock) is supported on $check_dir."
else
    echo -e "${RED}[FAIL]${NC} File locking is NOT supported. SQLite and Posit services will fail."
fi
rm -f "${check_dir}/lockfile"

# ACL Support Check
if command -v setfacl >/dev/null 2>&1; then
    touch "${check_dir}/acl_test"
    setfacl -m u:nobody:r "${check_dir}/acl_test" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[PASS]${NC} ACLs are supported and working."
    else
        echo -e "${RED}[WARN]${NC} ACLs failed to apply. Check mount options (must include 'acl')."
    fi
    rm -f "${check_dir}/acl_test"
else
    echo -e "${YELLOW}[MISSING]${NC} 'acl' package not installed. Posit Workbench requires ACLs."
fi

# IO Ping / Latency Check (Simplified IO Ping)
echo -n "Checking Storage Latency (IO Ping)... "
latency=$( (time -p sh -c "dd if=/dev/zero of=${check_dir}/test_io bs=4k count=1000 conv=fdatasync && sync") 2>&1 | grep real | awk '{print $2}')
if (( $(echo "$latency < 1.0" | bc -l) )); then
    echo -e "${GREEN}[GOOD]${NC} ($latency sec)"
else
    echo -e "${YELLOW}[WARN]${NC} High Latency ($latency sec). Shared storage may be slow for high-concurrency."
fi
rm -f "${check_dir}/test_io"

# Swap space
echo -n "Checking Swap Status... "
swap_total=$(free | grep Swap | awk '{print $2}')
if [ "$swap_total" -eq 0 ]; then
    echo -e "${YELLOW}[WARN]${NC} No Swap space configured. Server may crash if RAM is exhausted."
else
    echo -e "${GREEN}[PASS]${NC} Swap is available ($swap_total KB)."
fi

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

# Check Internet Access
echo -e ${YELLOW}"Checking Internet Access (google.com):"${NC} && \
if ping -c 1 -W 2 google.com &> /dev/null; then
    echo -e "   ${BLUE}Internet:${GREEN} Available${NC}"
else
    echo -e "   ${BLUE}Internet:${RED} Not Available${NC}"
fi && \

# Network & Connectivity
echo -e "\n${YELLOW}--- Network & Port Availability ---${NC}"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}[PASS]${NC} Internet Access available."
else
    echo -e "${YELLOW}[WARN]${NC} No Internet Access (Offline installation required)."
fi

for port in 443 8787 3939 4242; do
    if ss -tuln | grep -q ":$port "; then
        echo -e "${RED}[WARN]${NC} Port $port is already in use."
    else
        echo -e "${GREEN}[OPEN]${NC} Port $port is available."
    fi
done

# Check Proxy Settings
echo -e ${YELLOW}"Checking Proxy Settings:"${NC} && \
echo -e "   HTTP Proxy: ${NC}$(echo ${HTTP_PROXY:-None})" && \
echo -e "   HTTPS Proxy: ${NC}$(echo ${HTTPS_PROXY:-None})" && \

# Runtimes
echo -e "\n${YELLOW}--- Language Runtimes (/opt/) ---${NC}"
for lang in "R" "python" "quarto"; do
    if [ -d "/opt/$lang" ]; then
        versions=$(ls /opt/$lang | tr '\n' ' ')
        echo -e "${GREEN}[FOUND]${NC} /opt/$lang: $versions"
    else
        echo -e "${YELLOW}[MISSING]${NC} /opt/$lang"
    fi
done

# SSL/TLS Certificate Bundle Check
echo -e "\n${YELLOW}--- Checking System SSL Bundle ---${NC}" && \
bundles=("/etc/ssl/certs/ca-certificates.crt" "/etc/pki/tls/certs/ca-bundle.crt" "/etc/ssl/ca-bundle.pem")
found_bundle=""
for b in "${bundles[@]}"; do
    if [ -f "$b" ]; then found_bundle="$b"; break; fi
done

if [ -n "$found_bundle" ]; then
    echo -e "${GREEN}[FOUND]${NC} ($found_bundle)"
else
    echo -e "${RED}[FAIL]${NC} No system SSL bundle found. Outbound HTTPS will fail."
fi

# End
echo -e "\n${YELLOW}--- End of Readiness Check ---${NC}"
