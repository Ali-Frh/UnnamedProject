#!/bin/bash
DB="users.db" 
delete_user() {
    echo -e "${BLUE}Deleting a user...${NC}"
    read -p "Enter username to delete: " username
    userdel -r "$username" 2>/dev/null
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    echo -e "${GREEN}User '$username' deleted successfully!${NC}"
}
