# Marple installation

This repository contains everything you need to set up [Marple](https://marpledata.com) on-premise.

⚠️ You need a trial license to run the software, so get in touch with [support@marpledata.com](mailto:support@marpledata.com) before you get started.


## Requirements

Marple requires the following software
- [Docker-compose](https://docs.docker.com/compose/)
- [PostgreSQL](https://www.postgresql.org/) server (optionally, see _"Using an external Postgres"_ below)

The minimal specs for the docker environment are
- Linux (x86, ARM is not supported)
- 8 GB RAM
- 4 vCPU
- 20 GB storage, that can be mounted as a [volume](https://docs.docker.com/storage/volumes/)
- A working internet connection, to pull the Marple container
- A network connection for clients to connect, with 100 Mbit/s upload speed, and equal or better download speed


## Set up

⚠️ This instructions assume you are setting up Marple on a virtual machine (VM). If you want to run the container directly in the cloud, some steps are not relevant.

1. Verify that you got the following info from the Marple team
    - A `license.json` file
    - Credentials for the docker registry
    - A deployment name
2. Clone or [download](https://gitlab.com/marple-public/marple-installation/-/archive/master/marple-installation-master.zip) this repository
3. Edit `.env`, and set
    - `MARPLE_DEPLOYMENT` = the deployment name you got from the Marple team
    - `MARPLE_PUBLIC_URL` = the hostname where the application will be reachable
    - `MARPLE_IS_OFFLINE` = true (this will disable auth0 external authentication)
    - `MARPLE_HOME` = path to a directory (volume) where configuration files can be stored
    - `MARPLE_FILESYSTEM` = path where data files can be stored, can be the same as `MARPLE_HOME`
4. (Optionally) configure an external Postgres. In the same `.env`, set
    - `MARPLE_POSTGRES_HOST` = IP or hostname
    - `MARPLE_POSTGRES_PORT` = port exposed by PostgreSQL, usually 5432
    - `MARPLE_POSTGRES_USER` = postgres user
    - `MARPLE_POSTGRES_PW` = password for this user
    - `MARPLE_POSTGRES_DB_NAME` = name of a clean database inside the server
5. Put the `license.json` file in `MARPLE_HOME`
6. Open a shell and authenticate with the docker registry with `docker login https://docker.getmarple.io`
7. Open a shell inside the directory with `docker-compose.yml`
8. Execute `docker-compose up -d` to start Marple
9. Verify that Marple runs on the desired URL. Finish the setup in Marple

## Using an external Postgres

By default, the Postgres database is run as a second container in docker-compose.You can choose to set it up externally, using:
- Database as a service (on AWS, GCP, Azure, ...)
- A separate VM
- A separate process on the same instance
- ...

If you do so, here are our recommendations:
- Use Postgres version 14
- Allocate at least 2 vCPU + 4GB RAM, but preferably more
- (Azure only) make sure the `UUID_OSSP` extension is enabled

To connect Marple to your Postgres, follow step 4 from the _"Set up"_ instructions above

## Security

Marple runs over HTTP by default. We strongly recommend to add additional security, as we do for [our own cloud offering](https://app.marpledata.com).

Possible measures are
- HTTPS (e.g. a reverse proxy in front of Marple)
- VPN (to only allow authorized users to access the host)

The Marple instance should be assigned to a fix URL to prevent phishing and establish trust in general.
Preferably someting like `marple.yourcompany.com`, but `marple-your-company.azurecontainers.com` can also work. Deploying at a raw IP like `212.123.3.242` should be avoided. Even worse would be an IP changing on each deployment.


## Backups

A backup system should be put in place, for
1. The raw data files (`.csv`, `.mat`, ...)
2. The postgres storage (containing user data, notes, etc among other things)


## Updating

1. Edit `docker-compose.yml`
2. Set the marple container version to the latest version, e.g. `2.6.0`
3. `docker-compose pull`
4. `docker-compose up -d`
5. Verify that Marple is the latest version by checking the "Settings" → "About" screen
