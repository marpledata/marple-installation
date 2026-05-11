# Marple On Prem Quickstart

## 1. Requirements

- Docker Engine ≥ 24
  - Verify installation `docker --version`
  - [Install](https://docs.docker.com/engine/install/) if missing
- Docker Compose plugin ≥ 2.20
  - Verify installation `docker compose version`
  - [Install](https://docs.docker.com/compose/install/) if missing
- 16 GB memory (32 GB if running Keycloak)
- 64 GB free storage (containers + data)
- Internet access once to pull images, or use an online machine to `docker pull`, `docker save`, transfer the archives, then `docker load` on the offline host
- https. If you cannot request https certificates, follow the README of marple-airgap instead

## 2. DNS & HTTPS

- Set up a DNS entry for
  - Insight (e.g. https://insight.marple.example.com)
  - DB (e.g. https://db.marple.example.com)
  - Trino (e.g. https://trino.marple.example.com)
  - Dex/Keycloack (optional, in case you don't bring your own IdP)
- Configure routing & certificates. E.G. using `nginx` & `certbot` on Ubuntu:
  - Enter the new DNS entries into `marple.conf`
  - Add marple `marple.conf` to `/etc/nginx/sites-enabled/marple.conf`
  - `systemctl enable nginx`
  - `systemctl start nginx`
  - `snap install --classic certbot`
  - `sudo /snap/bin/certbot --nginx`

## 3. Trino Settings

Ensure Trino has full access to its configuration & spill directory. (Change the target directories as needed)

- `chmod -R 777 marple-installation/marple-on-prem/trino`
- `chmod -R 777 $DOCKER_PATH_ROOT/swap/trino`

## 4. Start Docker Services

Rename the `.env.example` file to `.env` and set the required fields:

- `DEPLOYMENT`
- `AWS_ACCESS_KEY` This will be generated later
- `AWS_SECRET_KEY` This will be generated later
- Check all variables flagged with "TODO"
- Other variables are optional

```bash
docker login docker.marpledata.com # log in with a robot account provided by Marple
docker compose up -d
docker compose ps
```

### a. Local Object Storage Configuration (Garage)

_Can be skipped if using a seperate S3-compatible blob storage_

If using the local object storage (Garage), you'll need to configure it when running Marple for the first time.

- Create a Temporary alias for running commands in the garage container:
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
- Generate a key and copy to Key ID & Secret key to [.env](.env)

  ```bash
  garage key create mdb-key
  ```

  - [./.env](.env)/`AWS_ACCESS_KEY` = `Key ID`
  - [./.env](.env)/`AWS_SECRET_KEY` = `Secret key`

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
   - Change the variables with # TODO in the dex-config.yaml file
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
  - `docker run marple-db poetry run python configure-s3-cors -o https://db.marple.example.com`

## 5. Set up your workspaces

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

## 6. Configuration

- Most settings are configurable via the `.env` file
- Dex settings are in `dex-config.yaml`
- Keycloak settings can be edited in `marple-realm.json`
  - Find/replace `http://localhost` with your preferred redirect URL

## 7. Troubleshooting

- If you are stuck on “You are not part of any workspace” in DB, the database might not be initialised correctly (happens if the postgres container took to long to start). In this case, restart the marple-db container.
- `docker compose logs SERVICE` to inspect the docker logs
- Use a `.wslconfig` file on Windows to configure the amount of RAM available
