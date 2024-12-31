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

# Function to calculate remaining days
calculate_remaining_days() {
    local created_date=$1
    local current_date=$(date +%Y-%m-%d)
    local remaining_days=$(( ($(date -d "$current_date" +%s) - $(date -d "$created_date" +%s)) / 86400 ))
    echo $(( VALIDITY_PERIOD - remaining_days ))
}

# Function to list all users with colored output
list_users() {
    echo -e "${BLUE}Listing all users:${NC}"
    echo -e "${GREEN}---------------------------------------------------------------${NC}"
    
    # Fetch all users from the database
    users=$(sqlite3 "$DB" "SELECT username, quota, speed, created_date, used_traffic FROM users;")
    
    # Check if there are any users
    if [[ -z "$users" ]]; then
        echo -e "${RED}No users found.${NC}"
        return
    fi

    # Print each user with colored output
    echo -e "${CYAN}Username\tQuota\t\tSpeed\tCreated Date\tUsed Traffic\tStatus${NC}"
    echo -e "${GREEN}---------------------------------------------------------------${NC}"
    while IFS='|' read -r username quota speed created_date used_traffic; do
        remaining_days=$(calculate_remaining_days "$created_date")
        if [[ $remaining_days -lt 0 ]]; then
            status="${RED}Expired${NC}"
        else
            status="${GREEN}Active (${remaining_days} days left)${NC}"
        fi
        echo -e "${YELLOW}$username\t${MAGENTA}$quota\t${CYAN}$speed\t${GREEN}$created_date\t${RED}$used_traffic\t${status}${NC}"
    done <<< "$users"
}

# Initialize database
initialize_db() {
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        quota INTEGER,
        speed INTEGER,
        created_date TEXT,
        used_traffic INTEGER DEFAULT 0
    );"
}

initialize_db
list_users
