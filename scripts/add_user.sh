#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

echo "Registering user: $USERNAME"
docker exec synapse register_new_matrix_user -u "$USERNAME" -p "$PASSWORD" -c /data/homeserver.yaml --no-admin

echo "User $USERNAME has been registered successfully."
