# Airgapped Marple Deployment

This bundle provisions a self-contained Marple stack for offline or airgapped environments using `docker compose`. It includes Marple Insight, Marple DB, PostgreSQL, MinIO, and a bundled identity provider (Dex by default, Keycloak optional).

## 1. Quickstart

All services assume `marple.local` resolves to the local host. This is important! Add an entry:

```bash
sudo sh -c 'echo "127.0.0.1 marple.local" >> /etc/hosts'
```

On Windows, edit the hosts file with administrator privileges and add the same line.

The `docker-compose.yaml` & .env file have been configured to

## 1. Prerequisites

- Docker Engine ≥ 24 and Docker Compose plugin ≥ 2.20 on the offline host.
- At least 8 GB RAM and 4 CPU cores available.
- Ability to modify the host `hosts` file (`/etc/hosts` on macOS/Linux, `%SystemRoot%\System32\drivers\etc\hosts` on Windows).
- A workstation with internet access (the “staging host”) to download container images and copy them to the offline environment.

## 2. Directory Contents

- `docker-compose.yaml` — service definitions for the stack.
- `dex-config.yaml` — default Dex configuration (local user database).
- `marple-realm.json` — preconfigured Keycloak realm (used only if Keycloak is enabled).
- `.env` — **not committed**. You must create this file with deployment-specific settings.

## 3. Prepare Container Images (Airgap Workflow)

1. On the staging host (with internet):
   - Log in to Marple’s registry if required: `docker login docker.marpledata.com`.
   - Pull the images referenced in `docker-compose.yaml`:
     - `docker.marpledata.com/library/marple:${VERSION_INSIGHT}`
     - `docker.marpledata.com/library/marpledb:${VERSION_DB}`
     - `postgres:18-alpine`, `minio/minio`, `minio/mc`, `dexidp/dex:latest-alpine` (and `quay.io/keycloak/keycloak:latest` if you plan to use Keycloak).
   - Save them to archives: `docker save IMAGE_TAG -o IMAGE_TAG.tar`.
2. Transfer the `.tar` archives to the offline host via approved media.
3. On the offline host, load the images: `docker load -i IMAGE_TAG.tar`.

## 5. Configure Hostname Resolution

All services assume `marple.local` resolves to the local host. Add an entry:

```bash
sudo sh -c 'echo "127.0.0.1 marple.local" >> /etc/hosts'
```

On Windows, edit the hosts file with administrator privileges and add the same line.

## 6. Choose an Identity Provider

### Dex (default)

- Dex runs with the configuration in `dex-config.yaml`.
- Default local admin user:
  - Username: `admin`
  - Email: `admin@marpledata.com`
  - Password hash is stored in config; set an initial password via `dex` CLI or replace the bcrypt hash before deployment.
- Ensure `.env` values point to Dex:
  - `OIDC_DOMAIN=http://marple.local:8080`
  - `OIDC_ISSUER=http://marple.local:8080`
  - `OIDC_CLIENT=marple-client`
  - `OIDC_AUDIENCE=marple-client`

### Keycloak (optional)

- Uncomment the `keycloak` service block in `docker-compose.yaml`.
- Provide database credentials in `.env` (same as PostgreSQL service).
- Import realm automatically using the mounted `marple-realm.json`.
- Update `.env` accordingly:
  - `OIDC_ISSUER=http://marple.local:8080/realms/marple`
  - `OIDC_AUDIENCE=account`
- After first start, log in at `http://localhost:8080` with the credentials you configure (default admin if defined via `.env`).

## 7. Start the Stack

```bash
docker compose up -d
```

Check container status: `docker compose ps`.

## 8. Access the Services

- Marple Insight UI: `http://localhost` (mapped from `COMPOSE_PORT_MARPLE`, default 80).
- Marple DB API: `http://localhost:8000`.
- MinIO Console: `http://localhost:9001` (credentials `admin/password` unless changed).
- Identity Provider:
  - Dex: `http://marple.local:8080`
  - Keycloak: `http://marple.local:8080/realms/marple` (OIDC discovery)

## 9. Initial Verification

1. Sign in at `http://localhost` using your configured OIDC credentials.
2. Upload a sample file through MinIO or via Marple Insight to confirm storage connectivity.
3. Verify database health: `curl http://localhost:8000/health`.

## 10. Maintenance Tips

- To stop services: `docker compose down`.
- To upgrade, repeat the image download/load process with new tags, update `VERSION_*`, then `docker compose pull` (if online) or `docker load` followed by `docker compose up -d`.
- Persistent data lives under `postgresql/`, `minio/`, `insight/`, and `db/`. Back these up regularly.

## 11. Troubleshooting

- `docker compose logs SERVICE` to inspect container logs.
- Ensure host clock is accurate; OIDC tokens are time-sensitive.
- If OIDC login fails:
  - Confirm `OIDC_*` settings in `.env`.
  - Check that `marple.local` resolves correctly.
  - For Dex local users, verify the bcrypt hash in `dex-config.yaml`.
