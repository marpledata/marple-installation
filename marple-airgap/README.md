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

Open `C:\Windows\System32\drivers\etc\hosts` in Notepad (Run as Administrator) and add at the bottom:

```bash
127.0.0.1 marple.local
```

## 3. Start Everything

Edit the `.env` file and set the required fields:
- `DEPLOYMENT`
- `AWS_ACCESS_KEY` This will be generated later
- `AWS_SECRET_KEY` This will be generated later
- Other variables are optional


```bash
docker login docker.marpledata.com # log in with a robot account provided by Marple
docker compose up -d
docker compose ps
```

The first time you run this, the local object storage (Garage) must be configured:
   - Create a Temporary alias for running commands in the garage container:
      ```bash
      alias garage="docker exec -ti marple-airgap-garage-1 /garage"
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
      - [dev/.env](.env)/`AWS_ACCESS_KEY` = `Key ID`
      - [dev/.env](.env)/`AWS_SECRET_KEY` = `Secret key`
   - Allow the newly created key to manage the `mdb` bucket
      ```bash
      garage bucket allow --read --write --owner mdb --key mdb-key
      ```
   - Restart the containers to use the correct env variables:
      ```bash
      docker compose down
      docker compose up -d
      ```

## 4. Sign In

- Default Login: `admin@marpledata.com` / `password`
- Marple DB API: `http://localhost:8000`
  - Copy `connection.json` to Marple Insight
- Marple Insight UI: `http://localhost`
  - Upload a license file as provided by Marple
  - Upload `connection.json`
  - Edit MarpleDB API URL to use the docker host IP: `http://172.17.0.1:8000/api/v1`
- Dex/Keycloak issuer: `http://marple.local:8080`

## 5. Configuration

- Most settings are configurable via the `.env` file
- Dex settings are in `dex-config.yaml`
- Keycloak settings can be edited in `marple-realm.json`
  - Find/replace `http://localhost` with your preferred redirect URL

## 6. Troubleshooting

- Always browse to `localhost`, and not `marple.local`
- `docker compose logs SERVICE` to inspect startup issues
- Use a `.wslconfig` file to configure amount of RAM (Windows)
