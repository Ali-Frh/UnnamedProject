#!/bin/bash

# Database file
DB="users.db"

# Validity period in days (e.g., 30 days)
VALIDITY_PERIOD=30

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to convert bytes to human-readable format
human_readable() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(( bytes / 1073741824 )) GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(( bytes / 1048576 )) MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(( bytes / 1024 )) KB"
    else
        echo "$bytes bytes"
    fi
}

# Function to calculate remaining days
calculate_remaining_days() {
    local created_at=$1
    local current_date=$(date +%Y-%m-%d)
    local remaining_days=$(( (VALIDITY_PERIOD - ($(date -d "$current_date" +%s) - $(date -d "$created_at" +%s)) / 86400) ))
    echo $remaining_days
}

# Function to get used traffic from SSH tc data
get_used_traffic() {
    local username=$1
    # Fetch used traffic for the user from tc
    used_traffic=$(tc -s qdisc show dev eth0 | grep "class .* $username" | awk '{print $6}')
    
    # If no traffic is found, default to 0
    if [[ -z "$used_traffic" ]]; then
        used_traffic=0
    fi

    echo "$used_traffic"
}

# Function to list all users with colored output
list_users() {
    echo -e "${BLUE}Listing all users:${NC}"
    echo -e "${GREEN}----------------------------------------------------------------------------------------${NC}"
    
    # Fetch all users from the database
    users=$(sqlite3 "$DB" "SELECT username, quota, speed, created_at FROM users;")
    
    # Check if there are any users
    if [[ -z "$users" ]]; then
        echo -e "${RED}No users found.${NC}"
        return
    fi

    # Print table header
    printf "%-15s %-15s %-10s %-15s %-15s %-15s %-20s\n" \
        "Username" "Quota" "Speed" "Created Date" "Used Traffic" "Left Traffic" "Status"
    echo -e "${GREEN}----------------------------------------------------------------------------------------${NC}"

    # Print each user with colored output
    while IFS='|' read -r username quota speed created_at; do
        used_traffic=$(get_used_traffic "$username")
        left_traffic=$(( quota - used_traffic ))
        remaining_days=$(calculate_remaining_days "$created_at")

        # Convert quota, used traffic, and left traffic to human-readable format
        quota_hr=$(human_readable "$quota")
        used_traffic_hr=$(human_readable "$used_traffic")
        left_traffic_hr=$(human_readable "$left_traffic")

        # Determine status
        if [[ $remaining_days -lt 0 ]]; then
            status="${RED}Expired (Time)${NC}"
        elif [[ $left_traffic -le 0 ]]; then
            status="${RED}Expired (Quota)${NC}"
        else
            if [[ $remaining_days -lt 2 ]]; then
                status="${RED}Active (${remaining_days} days, ${left_traffic_hr} left)${NC}"
            else
                status="${GREEN}Active (${remaining_days} days, ${left_traffic_hr} left)${NC}"
            fi
        fi

        # Print user details with proper alignment
        printf "%-15s %-15s %-10s %-15s %-15s %-15s %-20s\n" \
            "${YELLOW}$username${NC}" \
            "${MAGENTA}$quota_hr${NC}" \
            "${CYAN}$speed${NC}" \
            "${GREEN}$created_at${NC}" \
            "${RED}$used_traffic_hr${NC}" \
            "${MAGENTA}$left_traffic_hr${NC}" \
            "$status"
    done <<< "$users"
}

# Initialize database
initialize_db() {
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        quota INTEGER,
        speed INTEGER,
        created_at TEXT
    );"
}

initialize_db
list_users
