# Marple On Prem Quickstart

## 1. Requirements

- Docker Engine ≥ 24
  - Verify installation `docker --version`
  - [Install](https://docs.docker.com/engine/install/) if missing
- Docker Compose plugin ≥ 2.20
  - Verify installation `docker compose version`
  - [Install](https://docs.docker.com/compose/install/) if missing
- 16 GB memory
- 64 GB free storage (containers + data)
- Internet access once to pull images, or use an online machine to `docker pull`, `docker save`, transfer the archives, then `docker load` on the offline host
- https. If you cannot request https certificates, follow the README of marple-airgap instead

### Bundled Services

For convenience the compose file ships with everything Marple needs to run end-to-end. For production we strongly recommend swapping these out for managed alternatives.

| Bundled (development)  | Recommended for production                   |
| ---------------------- | -------------------------------------------- |
| Postgres container     | Managed Postgres (e.g. AWS RDS, Cloud SQL)   |
| Garage (S3-compatible) | Managed object storage (e.g. AWS S3)         |
| Dex / Keycloak         | Managed IdP (Auth0, Okta, Cognito, Entra ID) |

All three are configured via `.env` (`POSTGRES_*`, `MDB_AWS_*`, `OIDC_*` / `IDP_PROVIDER`).

## 2. DNS & HTTPS

- Set up a DNS entry for
  - Insight (e.g. https://insight.marple.example.com)
  - DB (e.g. https://db.marple.example.com)
  - Trino (e.g. https://trino.marple.example.com)
  - Dex/Keycloak (optional, in case you don't bring your own IdP)
- Configure routing & certificates. E.g. using `nginx` & `certbot` on Ubuntu:
  - Enter the new DNS entries into `marple.conf`
  - Add `marple.conf` to `/etc/nginx/sites-enabled/marple.conf`
  - `systemctl enable nginx`
  - `systemctl start nginx`
  - `snap install --classic certbot`
  - `sudo /snap/bin/certbot --nginx`

## 3. Start Docker Services

Rename the `.env.example` file to `.env` and set the required fields:

- `DEPLOYMENT`
- `MDB_AWS_ACCESS_KEY` This will be generated later
- `MDB_AWS_SECRET_KEY` This will be generated later
- Check all variables flagged with "TODO"
- Other variables are optional

```bash
docker login docker.marpledata.com # log in with a robot account provided by Marple
docker compose up -d
docker compose ps
```

### a. Local Object Storage Configuration (Garage)

_Can be skipped if using a separate S3-compatible blob storage_

If using the local object storage (Garage), you'll need to configure it when running Marple for the first time.

- Create a temporary alias for running commands in the garage container:
  ```bash
  alias garage="docker exec -ti marple-garage /garage"
  ```
- Get the id of this garage node to use in the next command:
  ```bash
  garage status
  ```
- Create a cluster layout, set the maximum storage capacity (in GB), take the node id from the previous command:
  ```bash
  garage layout assign --zone local --capacity <CAPACITY>G <NODE ID>
  ```
- Apply the layout:
  ```bash
  garage layout apply --version 1
  ```
- Create an `mdb` bucket:
  ```bash
  garage bucket create mdb
  ```
- Generate a key and copy the Key ID & Secret key into [.env](.env)

  ```bash
  garage key create mdb-key
  ```

  - [./.env](.env)/`MDB_AWS_ACCESS_KEY` = `Key ID`
  - [./.env](.env)/`MDB_AWS_SECRET_KEY` = `Secret key`

- Allow the newly created key to manage the `mdb` bucket
  ```bash
  garage bucket allow --read --write --owner mdb --key mdb-key
  ```
- Restart the containers to use the correct env variables:
  ```bash
  docker compose down
  docker compose up -d
  ```

### b. Configure OAUTH IdP

_Can be skipped if using 'OFFLINE' auth_

1. Dex:
   - Change the variables with # TODO in the `dex-config.yaml` file
   - Default user/pass = admin@marpledata.com/password
2. Keycloak:
   - Find/replace `http://localhost` with your preferred redirect URL
   - Or use the Keycloak Admin UI (default user/pass = admin@marpledata.com/password)
3. Other OAUTH/OIDC IdP:
   - Create a client for Marple (Single Page Application)
   - Configure redirect URLs
     - Allowed web origins: https://insight.marple.example.com, https://db.marple.example.com
     - Redirect callbacks: https://insight.marple.example.com, https://db.marple.example.com/login
     - Allowed logout URLs: https://insight.marple.example.com/logout, https://db.marple.example.com/logout
   - Fill in OIDC_DOMAIN, OIDC_ISSUER, OIDC_CLIENT, OIDC_AUDIENCE, OIDC_SCOPE as needed in the `.env` file

### c. Various

- Configure S3 CORS (Necessary to upload files via the DB UI)
  - `docker exec -it marple-db poetry run python configure-upload-cors -o https://db.marple.example.com`

## 4. Set up your workspaces

- Open Marple DB UI in the browser (https://db.marple.example.com)
  - Upload a license file as provided by Marple (if licensing server is disabled)
  - Settings -> Marple Insight
  - Fill in `Insight URL` + `Save`
  - Download `connection.json`

- Open Marple Insight
  - Upload a license file as provided by Marple (if licensing server is disabled)
  - Settings -> Connection
  - Upload `connection.json`

- Upload a file and verify you can visualise it in Insight

## 5. Configuration

- Most settings are configurable via the `.env` file
- Dex settings are in `dex-config.yaml`
- Keycloak settings can be edited in `marple-realm.json`
  - Find/replace `http://localhost` with your preferred redirect URL

## 6. Backups

If you do decide to use the bundled Postgres and/or Garage, set up at least a daily backup. **Copying the data directory while the containers are running can produce an unrestorable Postgres backup** — use `pg_dumpall` for the database and a `tar` snapshot for object storage. Save the script as e.g. `/usr/local/bin/marple-backup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

RETENTION_DAYS="${1:-7}"
DATA_ROOT="${DATA_ROOT:-/srv/marple/data}"          # matches COMPOSE_PATH_ROOT in .env
BACKUP_ROOT="${BACKUP_ROOT:-/srv/marple/backups}"
DAILY="$BACKUP_ROOT/$(date +%F)"

mkdir -p "$DAILY"
echo "Backing up to $DAILY"

# Postgres: logical dump (safe while the DB is live)
docker exec -t marple-postgres \
  pg_dumpall -U "${POSTGRES_USER:-marple}" \
  | gzip > "$DAILY/postgres.sql.gz"

# Garage object storage: tar the on-disk data + meta
tar -C "$DATA_ROOT" -czf "$DAILY/garage.tgz" garage

# (Optional) ship off-host so a disk loss doesn't take the backups with it
# aws s3 sync "$DAILY" "s3://my-backups/marple/$(date +%F)/"

# Prune old daily folders
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
     -mtime "+$RETENTION_DAYS" -exec rm -rf {} +
```

Then schedule it to run daily (e.g. at 02:00) via `crontab -e`:

```cron
0 2 * * * /usr/local/bin/marple-backup.sh >> /var/log/marple-backup.log 2>&1
```

> **Test the restore path at least once.** An untested backup is a hope, not a backup.

To restore from a `$DAILY` folder, stop the stack, put the Garage data back on disk, then replay the Postgres dump against a fresh container:

```bash
DAILY=/srv/marple/backups/YYYY-MM-DD          # folder to restore from
DATA_ROOT=/srv/marple/data                    # matches COMPOSE_PATH_ROOT in .env

docker compose down

# Garage: wipe the existing data dir and extract the snapshot back in place
rm -rf "$DATA_ROOT/garage"
tar -C "$DATA_ROOT" -xzf "$DAILY/garage.tgz"

# Postgres: start only the DB, drop the old contents, replay the dump
docker compose up -d postgres
gunzip -c "$DAILY/postgres.sql.gz" \
  | docker exec -i marple-postgres psql -U "${POSTGRES_USER:-marple}" -d postgres

docker compose up -d
```

## 7. Troubleshooting

- If you are stuck on “You are not part of any workspace” in DB, the database might not be initialised correctly (happens if the postgres container took too long to start). In this case, restart the marple-db container.
- `docker compose logs SERVICE` to inspect the docker logs
- Use a `.wslconfig` file on Windows to configure the amount of RAM available
- If the docker logs show `Self-signed certificate` errors (common when a corporate proxy or internal CA intercepts TLS), mount the host's CA certificates into the containers and point `REQUESTS_CA_BUNDLE` at the bundle. On Debian/Ubuntu hosts, install your internal CA with `update-ca-certificates` first; it then ends up in `/etc/ssl/certs/ca-certificates.crt`. In `docker-compose.yaml`, the Marple services share their volumes and environment via the `x-*` blocks at the top of the file, so add it there (once for Insight, once for DB):

  ```yaml
  x-mdb-volumes: &mdb-volumes # ... existing entries ...
    - /etc/ssl/certs:/etc/ssl/certs:ro

  x-mdb-environment: &mdb-environment # ... existing entries ...
    REQUESTS_CA_BUNDLE: /etc/ssl/certs/ca-certificates.crt
  ```

  Repeat the same for `x-insight-volumes` / `x-insight-environment`, then recreate the containers with `docker compose up -d`.

  Note: `REQUESTS_CA_BUNDLE` must point at a bundle _file_ (or an OpenSSL-hashed directory, i.e. one processed by `c_rehash`/`update-ca-certificates`).
