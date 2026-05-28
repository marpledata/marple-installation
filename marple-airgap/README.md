# Marple Airgap Quickstart

Use Marple Airgap in case you want to set up Marple without IdP.
Want to set up your own IdP on Marple? Follow the readme of marple-on-prem.

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

## 2. Start Docker Compose Services

Rename the `.env.example` file to `.env` and set the required fields:

- `DEPLOYMENT`
- `AWS_ACCESS_KEY` This will be generated later
- `AWS_SECRET_KEY` This will be generated later
- Check all variables flagged with "TODO"
- Other variables are optional

Pull and start the docker containers by executing

```bash
docker login docker.marpledata.com # log in with a robot account provided by Marple
docker compose up -d
docker compose ps
```

### a. Garage (Blob Storage) Configuration

_If using your own Blob storage, this part can be skipped_

If using the local object storage (Garage), you'll need to configure it when running Marple for the first time.

- Create a Temporary alias for running commands in the garage container:
  #### Unix/MacOS
  ```bash
  alias garage="docker exec -ti marple-garage /garage"
  ```
  #### Powershell
  ```powershell
  function garage { docker exec -ti marple-garage /garage $args }
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
- Generate a key (you'll need this in the next steps)
  ```bash
  garage key create mdb-key
  ```
- Allow the newly created key to manage the `mdb` bucket
  ```bash
  garage bucket allow --read --write --owner mdb --key mdb-key
  ```
- Copy the generated bucket Key ID & Secret key to [.env](.env)
  - [./.env](.env)/`AWS_ACCESS_KEY` = `Key ID`
  - [./.env](.env)/`AWS_SECRET_KEY` = `Secret key`
- Restart the containers to use the correct env variables:
  ```bash
  docker compose down
  docker compose up -d
  ```

## 4. Set up your workspaces

- Default Login: chose your account name
- Open Marple DB UI in the browser: `http://localhost:8001`
  - Upload a license file as provided by Marple (if licensing server is disabled)
  - Settings -> Marple Insight
  - Fill in `Insight URL=http://localhost:8000` + `Save`
  - Download `connection.json`
- Open Marple Insight UI: `http://localhost:8000`
  - Upload a license file as provided by Marple (if licensing server is disabled)
  - Upload `connection.json`
  - In case of localhost: edit `MarpleDB API URL` in Authentication tab to use the docker host IP: `http://172.17.0.1:8001/api/v1`
- Upload a file and verify you can visualise it in Insight

## 5. Configure DNS and nginx (Optional)

In case you like to set up DNS + nginx:

- Follow DNS setup in `marple-on-prem/README.md`
- Remove the IdP parts from `marple.conf`, since those are redundant in an airgapped setup.

## 6. Troubleshooting

- If you are stuck on “You are not part of any workspace” in DB, the database might not be initialised correctly (happens if the postgres container took to long to start). In this case, restart the marple-db container.
- `docker compose logs SERVICE` to inspect the docker logs
- Use a `.wslconfig` file on Windows to configure the amount of RAM available
