# Marple Airgap Quickstart

## 1. Requirements

- Docker Engine ≥ 24
- Docker Compose plugin ≥ 2.20
- 16 GB memory (32 GB if running Keycloak)
- 64 GB free storage (containers + data)
- Internet access once to pull images, or use an online machine to `docker pull`, `docker save`, transfer the archives, then `docker load` on the offline host

## 2. Point `marple.local` to localhost

Add `127.0.0.1 marple.local` to the hosts file:

#### Unix/MacOS

```bash
sudo sh -c 'echo "127.0.0.1 marple.local" >> /etc/hosts'
```

#### Windows

Open `C:\Windows\System32\drivers\etc\hosts` in Notepad (Run as Administrator) and add the same line.

## 3. Start Everything

Edit the `.env` file and set the required fields (only DEPLOYMENT is required)

```bash
docker login docker.marpledata.com # log in with a robot account provided by Marple
docker compose up -d
docker compose ps
```

## 4. Sign In

- Default Login: `admin@marpledata.com` / `password`
- Marple DB API: `http://localhost:8000`
  - Copy `connection.json` to Marple Insight
- Marple Insight UI: `http://localhost`
  - Upload a license file as provided by Marple
  - Upload `connection.json`
  - Edit MarpleDB API URL to use the docker host IP: `http://172.17.0.1:8000/api/v1`
- MinIO Console: `http://localhost:9001` (default `admin/password`)
- Dex/Keycloak issuer: `http://marple.local:8080`

## 5. Configuration

- Most settings are configurable via the `.env` file
- Dex settings are in `dex-config.yaml`
- Keycloak settings can be edited in `marple-realm.json`
  - Find/replace `http://localhost` with your preferred redirect URL

## 6. Troubleshooting

- Always browse to `localhost`, and not `marple.local`
- `docker compose logs SERVICE` to inspect startup issues
