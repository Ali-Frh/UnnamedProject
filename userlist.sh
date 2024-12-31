#!/bin/bash

# Database file
DB="users.db"

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
    local expired_at=$1
    local current_date=$(date +%Y-%m-%d)
    local remaining_days=$(( ($(date -d "$expired_at" +%s) - $(date -d "$current_date" +%s)) / 86400 ))
    echo $remaining_days
}

# Function to get used traffic from tc data
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

# Function to list all users
list_users() {
    echo "Listing all users:"
    echo "----------------------------------------------------------------------------------------"
    
    # Fetch all users from the database
    users=$(sqlite3 "$DB" "SELECT username, quota, speed, created_at, expired_at FROM users;")
    
    # Check if there are any users
    if [[ -z "$users" ]]; then
        echo "No users found."
        return
    fi

    # Print table header
    printf "%-15s %-15s %-10s %-15s %-15s %-15s %-20s\n" \
        "Username" "Quota" "Speed" "Created At" "Expired At" "Used Traffic" "Status"
    echo "----------------------------------------------------------------------------------------"

    # Print each user
    while IFS='|' read -r username quota speed created_at expired_at; do
        used_traffic=$(get_used_traffic "$username")
        left_traffic=$(( quota * 1024 * 1024 - used_traffic ))
        remaining_days=$(calculate_remaining_days "$expired_at")

        # Convert traffic to human-readable format
        quota_hr=$(human_readable "$(( quota * 1024 * 1024 ))")
        used_traffic_hr=$(human_readable "$used_traffic")
        left_traffic_hr=$(human_readable "$left_traffic")

        # Determine status
        if [[ $remaining_days -lt 0 ]]; then
            status="Expired (Time)"
        elif [[ $left_traffic -le 0 ]]; then
            status="Expired (Quota)"
        else
            status="Active ($remaining_days days, $left_traffic_hr left)"
        fi

        # Print user details
        printf "%-15s %-15s %-10s %-15s %-15s %-15s %-20s\n" \
            "$username" \
            "$quota_hr" \
            "$speed" \
            "$created_at" \
            "$expired_at" \
            "$used_traffic_hr" \
            "$status"
    done <<< "$users"
}

# Initialize database
initialize_db() {
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        password TEXT,
        quota INTEGER,
        speed INTEGER,
        created_at TEXT,
        expired_at TEXT
    );"
}

initialize_db
list_users
