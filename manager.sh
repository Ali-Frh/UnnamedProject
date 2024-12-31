#!/bin/bash

# Database file
DB_FILE="users.db"

# Initialize SQLite database
initialize_db() {
    sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        quota INTEGER NOT NULL,
        speed INTEGER NOT NULL,
        used INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        password TEXT NOT NULL
    );"
}

# Add a new user
add_user() {
    local username=$1
    local quota=$2
    local speed=$3
    local created_at=$4
    local password=$5

    # Validate date format
    if ! [[ "$created_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Invalid date format. Please use YYYY-MM-DD."
        return
    fi

    # Convert MB to bytes for quota
    quota_bytes=$((quota * 1024 * 1024))

    # Create SSH user
    useradd -m -s /usr/sbin/nologin "$username"
    echo "$username:$password" | chpasswd

    # Insert into database
    sqlite3 "$DB_FILE" "INSERT INTO users (username, quota, speed, created_at, password) VALUES ('$username', $quota_bytes, $speed, '$created_at', '$password');"

    # Apply traffic control rules
    sudo tc class add dev tun0 parent 1:1 classid 1:$((RANDOM % 1000)) htb rate ${speed}mbit ceil ${speed}mbit
    sudo iptables -A OUTPUT -t mangle -p tcp -m owner --uid-owner $username -j MARK --set-mark $((RANDOM % 1000))
    sudo tc filter add dev tun0 protocol ip parent 1:0 prio 1 handle $((RANDOM % 1000)) fw flowid 1:$((RANDOM % 1000))

    echo "User $username added with quota ${quota}MB, speed limit ${speed}MB/s, creation date $created_at, and password $password."
}

# Check how much traffic a user has used
check_usage() {
    local username=$1
    result=$(sqlite3 "$DB_FILE" "SELECT used, quota, created_at FROM users WHERE username='$username';")

    if [ -z "$result" ]; then
        echo "User $username not found."
    else
        IFS='|' read -r used quota created_at <<< "$result"
        used_mb=$((used / 1024 / 1024))
        quota_mb=$((quota / 1024 / 1024))
        echo "User $username has used ${used_mb}MB out of ${quota_mb}MB (Created on: $created_at)."
    fi
}

# Delete a user
delete_user() {
    local username=$1

    # Remove from database
    sqlite3 "$DB_FILE" "DELETE FROM users WHERE username='$username';"

    # Remove SSH user
    userdel -r "$username"

    # Remove traffic control rules
    sudo iptables -D OUTPUT -t mangle -p tcp -m owner --uid-owner $username -j MARK --set-mark $((RANDOM % 1000))

    echo "User $username deleted."
}

# Main menu
main_menu() {
    echo "Traffic Management System"
    echo "1. Add User"
    echo "2. Check Usage"
    echo "3. Delete User"
    echo "4. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1)
            read -p "Enter username: " username
            read -p "Enter quota (in MB): " quota
            read -p "Enter speed limit (in MB/s): " speed
            read -p "Enter creation date (YYYY-MM-DD): " created_at
            read -p "Enter password: " password
            add_user "$username" "$quota" "$speed" "$created_at" "$password"
            ;;
        2)
            read -p "Enter username: " username
            check_usage "$username"
            ;;
        3)
            read -p "Enter username: " username
            delete_user "$username"
            ;;
        4)
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac
}

# Initialize the database
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
                check_usage "$2"
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
        *)
            echo "Invalid command. Use adduser, getusage, or deleteuser."
            ;;
    esac
else
    # Show menu if no arguments are provided
    while true; do
        main_menu
    done
fi
