#!/bin/bash

DB="users.db"

# Initialize SQLite database
initialize_db() {
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        quota INTEGER,
        speed INTEGER,
        created_date TEXT,
        used_traffic INTEGER DEFAULT 0,
        password TEXT
    );"
}

# Add a user
add_user() {
    local username=$1
    local quota=$2
    local speed=$3
    local date=$4
    local password=$5

    # Convert quota to bytes (e.g., 10MB -> 10485760)
    if [[ $quota =~ [0-9]+[mM][bB] ]]; then
        quota=$(echo "${quota%[mM][bB]} * 1024 * 1024" | bc)
    fi

    # Insert user into the database
    sqlite3 "$DB" "INSERT INTO users (username, quota, speed, created_date, password) VALUES ('$username', $quota, $speed, '$date', '$password');"
    echo "User $username added with quota $quota bytes, speed $speed MB/s, date $date, and password $password."
}

# Get usage and remaining days
get_usage() {
    local username=$1
    local current_date=$(date +%Y-%m-%d)
    local created_date=$(sqlite3 "$DB" "SELECT created_date FROM users WHERE username='$username';")
    local used_traffic=$(sqlite3 "$DB" "SELECT used_traffic FROM users WHERE username='$username';")
    local quota=$(sqlite3 "$DB" "SELECT quota FROM users WHERE username='$username';")

    if [[ -z $created_date ]]; then
        echo "User $username not found."
        return
    fi

    # Calculate remaining days
    local remaining_days=$(( ($(date -d "$current_date" +%s) - $(date -d "$created_date" +%s)) / 86400 ))
    local remaining_traffic=$(( quota - used_traffic ))

    echo "User: $username"
    echo "Used Traffic: $used_traffic bytes"
    echo "Remaining Traffic: $remaining_traffic bytes"
    echo "Remaining Days: $remaining_days"
}

# Delete a user
delete_user() {
    local username=$1
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    echo "User $username deleted."
}

# Edit user quota
edit_quota() {
    local username=$1
    local new_quota=$2

    # Convert quota to bytes (e.g., 10MB -> 10485760)
    if [[ $new_quota =~ [0-9]+[mM][bB] ]]; then
        new_quota=$(echo "${new_quota%[mM][bB]} * 1024 * 1024" | bc)
    fi

    sqlite3 "$DB" "UPDATE users SET quota=$new_quota WHERE username='$username';"
    echo "Quota for user $username updated to $new_quota bytes."
}

# Main menu
menu() {
    echo "1. Add User"
    echo "2. Get Usage"
    echo "3. Delete User"
    echo "4. Edit Quota"
    echo "5. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1)
            read -p "Username: " username
            read -p "Quota (e.g., 10MB): " quota
            read -p "Speed (MB/s): " speed
            read -p "Date (YYYY-MM-DD): " date
            read -p "Password: " password
            add_user "$username" "$quota" "$speed" "$date" "$password"
            ;;
        2)
            read -p "Username: " username
            get_usage "$username"
            ;;
        3)
            read -p "Username: " username
            delete_user "$username"
            ;;
        4)
            read -p "Username: " username
            read -p "New Quota (e.g., 10MB): " new_quota
            edit_quota "$username" "$new_quota"
            ;;
        5)
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac
}

# Initialize database
initialize_db

# Command-line arguments
if [[ $# -ge 1 ]]; then
    case $1 in
        adduser)
            if [[ $# -eq 6 ]]; then
                add_user "$2" "$3" "$4" "$5" "$6"
            else
                echo "Usage: $0 adduser <username> <quota> <speed> <date> <password>"
            fi
            ;;
        getusage)
            if [[ $# -eq 2 ]]; then
                get_usage "$2"
            else
                echo "Usage: $0 getusage <username>"
            fi
            ;;
        deleteuser)
            if [[ $# -eq 2 ]]; then
                delete_user "$2"
            else
                echo "Usage: $0 deleteuser <username>"
            fi
            ;;
        editquota)
            if [[ $# -eq 3 ]]; then
                edit_quota "$2" "$3"
            else
                echo "Usage: $0 editquota <username> <new_quota>"
            fi
            ;;
        *)
            echo "Invalid command. Use adduser, getusage, deleteuser, or editquota."
            ;;
    esac
else
    # Show menu if no arguments are provided
    while true; do
        menu
    done
fi
