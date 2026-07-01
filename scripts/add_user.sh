#!/bin/bash
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1

# Securely prompt for the user's password without echoing to terminal
read -s -p "Enter password for $USERNAME: " PASSWORD
echo ""

echo "Registering user: $USERNAME"
docker exec synapse register_new_matrix_user -u "$USERNAME" -p "$PASSWORD" -c /data/homeserver.yaml --no-admin

echo "User $USERNAME has been registered successfully."
