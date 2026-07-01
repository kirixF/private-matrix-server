# Technical Specification & Maintenance Guide for AI Agents

This document is designed for AI developers, coding assistants (e.g., Cursor, Windsurf, Antigravity, Claude, ChatGPT), and system administrators to understand, maintain, and troubleshoot this private Matrix server setup.

---

## 1. System Architecture & Stack

The application is deployed via Docker Compose on a single Ubuntu VPS.

*   **Synapse (Homeserver):** `matrixdotorg/synapse:v1.127.0`
*   **Element (Web Client):** `vectorim/element-web:v1.11.96`
*   **Database:** `postgres:16.3-alpine`
*   **Reverse Proxy:** `nginx:1.27-alpine`

### Network & Port Structure

Due to **AmneziaVPN** (`amnezia-xray` container) occupying the standard port **443** on the host, the Matrix stack runs on custom external ports:

*   **HTTP (Nginx):** Port `8081` on host maps to `80` in container.
*   **HTTPS (Nginx):** Port `4443` on host maps to `443` in container.

*Note: Inside the Nginx container, SSL is handled on port 443. The Nginx template configuration accounts for this port offset.*

---

## 2. Key Configurations

### Network Security
*   **PostgreSQL Isolation:** The database container `synapse_postgres` is attached *only* to a private internal network called `internal`. It cannot be reached from the host or the public internet.
*   **Synapse Network:** Attached to both `internal` (to talk to Postgres) and `default` (to talk to Nginx).
*   **Element Web & Nginx:** Attached to the `default` network.

### Rate Limiting & Performance
*   **Nginx Rate Limits:** Removed from `matrix.conf.template` because standard Nginx rate limiting causes synchronization failures (`503 Service Unavailable` or connection drops) in chatty mobile and desktop Matrix clients.
*   **Synapse Rate Limits (`homeserver.yaml`):** Default limits (burst of 3) are overridden at the bottom of the config to prevent `M_LIMIT_EXCEEDED` errors when multiple clients connect via Nginx (which masks their IPs). 
    ```yaml
    rc_login:
      address:
        per_second: 10
        burst_count: 100
      account:
        per_second: 10
        burst_count: 100
      failed_attempts:
        per_second: 10
        burst_count: 100
    ```

### Content Security Policy (CSP)
Element Web configuration in `nginx/templates/matrix.conf.template` uses a strict CSP header modified to whitelist the custom HTTPS port `4443` for API connections:
`connect-src 'self' https://${MATRIX_SUBDOMAIN}:4443`

---

## 3. Operations & User Management

### Creating a User
To register a new user, execute the script on the host:
```bash
./scripts/add_user.sh <username>
```
Or run the manual container command:
```bash
docker exec -it synapse register_new_matrix_user -u "<username>" -p "<password>" -c /data/homeserver.yaml --no-admin
```

### Resetting a Password (Important: Shell Escaping)
When updating a user's password directly in PostgreSQL, **always** use a heredoc or escape the `$` symbols in the hash to prevent the shell from expanding them:
```bash
docker exec -i synapse_postgres psql -U synapse -d synapse <<'EOF'
UPDATE users SET password_hash = '<HASH_HERE>' WHERE name LIKE '@<username>:%';
EOF
```
*Note: The database user is `synapse` (not postgres or synapse_user).*

---

## 4. Backups & Retention

The script `scripts/backup.sh` handles automated backups.
*   **Database Dump:** Dumps the `synapse` PostgreSQL database.
*   **Media Archive:** Tarballs `./synapse-data/media_store`.
*   **Encryption:** If `BACKUP_PASSWORD` is defined in `.env`, the final tarball is encrypted using GPG AES-256 (`.tar.gz.gpg`).
*   **Retention:** Deletes all backups older than 30 days automatically.
