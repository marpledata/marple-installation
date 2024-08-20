# Marple installation

This repository contains everything you need to set up [Marple](https://marpledata.com) on your own cloud or hardware.

⚠️ You need a trial license to run the software, so get in touch with [support@marpledata.com](mailto:support@marpledata.com) before you get started.

## What version of Marple do I need?

There are two product lines of Marple:

1. **Marple Connect**, which connects to an existing database with time series data
2. **Marple Files**, which can be used to import data files like `.csv`, `.tdms`, `.mat`, ...

Deployment files are respectively in `marple-connect/` and `marple-files/` in this repository.

Both of them can be deployed using [Kubernetes](https://kubernetes.io/). Marple Files can also be deployed using [Docker Compose](https://docs.docker.com/compose/). The instructions are outlined below.

## Deploying using Kubernetes

### Requirements

Software

- [Helm](https://helm.sh/)

Minimal specifications

- A running Kubernetes cluster
- 1 pod, with 4 vCPU and 8 GB RAM
- 1 volume with 20 GB of space for data, data exports etc.
- 1 volume for storing a secret (⚠ only required for Marple Connect)

### Set up

1. Verify that you got the following info from the Marple team
   - A `license.json` file
   - Credentials for the docker registry
   - A deployment name, and other required environment variables
2. Download `values.yaml` and `marple-{x.y.z}.tgz` from this repository
3. Edit `values.yaml`, and set all required values, indicated by `TODO`
4. Open a shell and authenticate with the docker registry with `docker login https://docker.getmarple.io`
5. Set a secret "docker-regcred" that contains the credentials for connecting with our registry _docker.getmarple.io_ ([guide](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/))
6. Execute `helm install marple-prod marple-{x.y.z}.tgz -f values.yaml` to deploy to kubernetes
7. Verify that Marple runs on the desired URL
8. Upload your `license.json` file in the UI
9. Finish additional configuration inside the UI

### Updating

1. Download the latest helm chart `marple-{x.y.z}.tgz`
2. Run `helm upgrade marple-pod marple-{x.y.z}.tgz -f values.yaml`
3. Verify that Marple is the latest version by checking the "Settings" → "About" screen

## Deploying using Docker Compose

⚠ This option is currently only available for Marple Files, not for Marple Connect (see explanation on top).

### Requirements

Software

- [Docker-compose](https://docs.docker.com/compose/)
- [PostgreSQL](https://www.postgresql.org/) server (optionally, see _"Using an external Postgres"_ below)

Minimal specifications

- Linux (x86, ARM is not supported)
- 4 vCPU, 8 GB RAM
- 20 GB storage, that can be mounted as a [volume](https://docs.docker.com/storage/volumes/)
- A working internet connection, to pull the Marple container
- A network connection, with 100 Mbit/s upload speed, and equal or better download speed

### Set up

1. Verify that you got the following info from the Marple team
   - A `license.json` file
   - Credentials for the docker registry
   - A deployment name
2. Download `.env` and `docker-compose.yaml` from this repository
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
8. Execute `docker compose up -d` to start Marple
9. Verify that Marple runs on the desired URL
10. Finish the setup in Marple

### Updating

1. Edit `docker-compose.yml`
2. Set the marple container version to the latest version, e.g. `2.6.0`
3. `docker-compose pull`
4. `docker-compose up -d`
5. Verify that Marple is the latest version by checking the "Settings" → "About" screen

## Using an external Postgres

Marple needs a Postgres database to work. If you are using Docker Compose, a second container with the database is included by default. If you are using Kubernetes, or you just want to run the Postgres separately, you will need to run a dedicated Postgres instance.

We recommend:

- Use Postgres version 14
- Allocate at least 2 vCPU + 4GB RAM, but preferably more
- (Azure only) make sure the `UUID_OSSP` extension is enabled

To connect Marple to your external Postgres, make sure to set all `MARPLE_POSTGRES_*` variables to the appropriate values.

## Backups

A backup system should be put in place, for

1. The storage volume
2. The Postgres database (containing user data, notes, etc among other things)

## Security

Marple runs over HTTP by default. We strongly recommend to add additional security, as we do for [our own cloud offering](https://app.marpledata.com).

Possible measures are

- HTTPS (e.g. a reverse proxy in front of Marple)
- VPN (to only allow authorized users to access the host)

The Marple instance should be assigned to a fix URL to prevent phishing and establish trust in general. Preferably someting like `marple.yourcompany.com`, but `marple-your-company.azurecontainers.com` can also work. This value should also be set in the application using the `MARPLE_PUBLIC_URL` environment variable.

Deploying at a raw IP like `212.123.3.242` should be avoided. Even worse would be an IP changing on each deployment.
