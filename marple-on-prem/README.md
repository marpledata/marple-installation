# Marple Airgap Quickstart

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

## 2. Fix DNS and nginx

- Set up DNS entry for 
   - Insight
   - DB
   - Trino
   - Dex/Keycloack (optional, in case you don't have your own IdP)
- Adapt `marple.conf` to the DNS new entries
- Move `marple.conf` to `/etc/nginx/sites-enabled/marple.conf`
- `systemctl enable nginx`
- `systemctl start nginx`
- `snap install --classic certbot`
- `sudo /snap/bin/certbot --nginx`
- `chmod -R 777 /path/to/trino/` (for trino folder in `/marple-on-prem`)

## 3. Start Everything

Edit the `.env` file and set the required fields:
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

The first time you run this, the local object storage (Garage) must be configured:
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

### Configure dex config
Optional, in case you don't link to your own IdP.
Change the variables with # TODO in the dex-config.yaml file.

## 4. Set up your workspaces

- Default Login: `admin@marpledata.com` / `password`
- Go to Marple DB
  - Copy `connection.json` to Marple Insight
- Go to Marple Insight
  - Upload `connection.json`
  - Edit MarpleDB API URL to use the docker host IP: `<insight origin>/api/v1`
- If you are stuck on “You are not part of any workspace” in DB, the database might not be initialised correctly (happens if the postgres container took to long to start). In this case, restart the marple-db container.
- Upload a file and verify you can visualise it in Inisght

## 5. Configuration

- Most settings are configurable via the `.env` file
- Dex settings are in `dex-config.yaml`
- Keycloak settings can be edited in `marple-realm.json`
  - Find/replace `http://localhost` with your preferred redirect URL

## 6. Troubleshooting

- `docker compose logs SERVICE` to inspect startup issues
- Use a `.wslconfig` file to configure amount of RAM (Windows)
