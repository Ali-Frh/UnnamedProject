#!/bin/bash
DB="users.db"
add_user() {
    echo -e "${BLUE}Adding a new user...${NC}"
    read -p "Enter username: " username
    read -p "Enter password: " password
    read -p "Enter quota (in MB): " quota
    read -p "Enter speed (in Mbps): " speed

    # Set created_at to the current date
    created_at=$(date +"%Y-%m-%d")

    # Ask for expiration date
    read -p "Enter expiration date (e.g., '1d' for 1 day or '2023-12-31'): " expire_input
    if [[ $expire_input == *d ]]; then
        days=${expire_input%d}
        expired_at=$(date -d "$created_at + $days days" +"%Y-%m-%d")
    else
        expired_at=$expire_input
    fi

    # Add user with nologin shell
    useradd -m -s /usr/sbin/nologin "$username"
    echo "$username:$password" | chpasswd

    # Apply traffic control rules
    sudo tc class add dev eth0 parent 1:1 classid 1:$((RANDOM % 1000)) htb rate ${speed}mbit ceil ${speed}mbit
    sudo iptables -A OUTPUT -t mangle -p tcp -m owner --uid-owner $username -j MARK --set-mark $((RANDOM % 1000))
    sudo tc filter add dev eth0 protocol ip parent 1:0 prio 1 handle $((RANDOM % 1000)) fw flowid 1:$((RANDOM % 1000))


    # Insert the user into the database
    sqlite3 "$DB" "INSERT INTO users (username, password, quota, speed, created_at, expired_at) VALUES ('$username', '$password', '$quota', '$speed', '$created_at', '$expired_at');"
    echo -e "${GREEN}User '$username' added successfully!${NC}"
}
add_user
