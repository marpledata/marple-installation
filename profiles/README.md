# Resource profiles

These files bundle every tunable that controls how much CPU and memory a Marple
deployment uses, so you can size a deployment with a single choice instead of
hand-tuning a dozen environment variables.

A profile sets three kinds of values:

1. **Container limits** (`*_MEM_LIMIT`, `*_CPU_LIMIT`) enforced by Docker Compose,
   so that if a container runs out of memory only that container is killed, not
   the whole host. By default only Trino gets a CPU cap; other services use
   `*_CPU_LIMIT=0` (unlimited) because the memory budget is the important OOM
   guardrail.
2. **Trino query budget** (`TRINO_QUERY_*`, `TRINO_HEAP_HEADROOM_PER_NODE`) that
   must fit inside the Trino container limit.
3. **Application worker counts** (`MDB_*`, `MARPLE_*`) that control how many
   processes and how much in-process concurrency each service runs.

## Pick a profile

| Profile                    | Target host   | Capped container budget | Use when                                          |
| -------------------------- | ------------- | ----------------------- | ------------------------------------------------- |
| [`small.env`](small.env)   | 2 CPU / 8 GB  | ~7 GB                   | Staging, small single-team deployments, test VMs  |
| [`medium.env`](medium.env) | 4 CPU / 16 GB | ~14 GB                  | Typical production for a single workspace or team |
| [`large.env`](large.env)   | 8 CPU / 32 GB | ~28 GB                  | Heavy ingestion, many workspaces, large queries   |

Each profile leaves headroom on the host for the OS, dockerd, and short-lived
spikes (Trino queries, Iceberg commit bursts, report/export browsers).

## How to apply a profile

### VPC split (`marple-db/` + `marple-insight/`)

These deployments run as separate Docker Compose stacks but share one resource
profile. Create `.env.profile` once at the **parent** of both directories (the
repository root if you keep the default layout). Each stack still has its own
`.env` for deployment-specific secrets; `docker-compose.yaml` loads both files.

```bash
# From the repository root (parent of marple-db/ and marple-insight/)
cp profiles/small.env .env.profile   # or medium.env / large.env

# marple-db stack
cd marple-db
cp .env.example .env
# fill in MDB_* / TRINO_* secrets, then:
docker compose up -d

# marple-insight stack (same host or another VM — reuse the same .env.profile)
cd ../marple-insight
cp .env.example .env
# fill in MARPLE_* secrets, then:
docker compose up -d
```

Copy `.env.profile` to every host that runs one of these stacks so both sides
use the same limits and worker counts. To switch profiles later, replace
`.env.profile` and restart both stacks.

### Single-stack (`marple-on-prem/`, `marple-airgap/`)

Append a profile into `.env` at provisioning time. The deployment only needs
`docker-compose.yaml` and `.env`.

```bash
# From the deployment directory
cp .env.example .env
cat ../profiles/small.env >> .env
# then fill in the deployment secrets at the top of .env and start:
docker compose up -d
```

To switch profiles later, edit the appended block in `.env` (or re-create `.env`
and append a different profile). When a key appears twice in `.env`, Docker
Compose uses the last occurrence, so an override placed at the very bottom wins.

## What each profile controls

### Container limits

| Variable                                            | small       | medium | large  |
| --------------------------------------------------- | ----------- | ------ | ------ |
| `TRINO_MEM_LIMIT` / `TRINO_CPU_LIMIT`               | 2g / 1      | 4g / 2  | 10g / 4 |
| `MDB_MEM_LIMIT` / `MDB_CPU_LIMIT`                   | 1g / 0      | 1g / 0  | 1g / 0  |
| `MDB_WORKER_MEM_LIMIT` / `MDB_WORKER_CPU_LIMIT`     | 2g / 0      | 4g / 0  | 8g / 0  |
| `MARPLE_MEM_LIMIT` / `MARPLE_CPU_LIMIT`             | 1g / 0      | 2g / 0  | 3g / 0  |
| `MARPLE_QUEUE_MEM_LIMIT` / `MARPLE_QUEUE_CPU_LIMIT` | 1g / 0      | 3g / 0  | 6g / 0  |

### Trino query budget

Trino sizes its JVM heap to ~80% of the container limit (see `jvm.config` in the
marple-db image), so the query budget must be set together with `TRINO_MEM_LIMIT`.
Two rules apply:

```
# startup validation (strict less-than)
TRINO_QUERY_MAX_MEMORY_PER_NODE + TRINO_HEAP_HEADROOM_PER_NODE < JVM heap

# concurrent queries (max-total is per query, not cluster-wide)
2 × TRINO_QUERY_MAX_TOTAL_MEMORY < JVM heap
```

If the first inequality fails, Trino refuses to start. The second keeps two
parallel spill-heavy queries from blowing past the heap.

| Variable                          | small | medium | large |
| --------------------------------- | ----- | ------ | ----- |
| `TRINO_QUERY_MAX_MEMORY`          | 512MB | 1GB    | 3GB   |
| `TRINO_QUERY_MAX_MEMORY_PER_NODE` | 512MB | 1GB    | 3GB   |
| `TRINO_HEAP_HEADROOM_PER_NODE`    | 384MB | 512MB  | 1GB   |
| `TRINO_QUERY_MAX_TOTAL_MEMORY`    | 768MB | 1.5GB  | 4GB   |

### Application workers

Not every worker setting spins up a process. This is the biggest source of
confusion when budgeting memory:

- `MDB_HEATING_WORKERS` and `MDB_INGEST_WORKERS` spawn **separate processes**.
- `MDB_COOLING_WORKERS` and `MDB_ICEBERG_WORKERS` are **procrastinate
  concurrency** inside a single worker process each (threads, not processes).
- `MDB_API_WORKERS` / `MARPLE_API_WORKERS` are **gunicorn worker processes**.
- `MARPLE_PROCRASTINATE_WORKERS` is concurrency inside the single insight queue
  process (each parallel export can launch a headless browser).

| Variable                           | small | medium | large | Kind                             |
| ---------------------------------- | ----- | ------ | ----- | -------------------------------- |
| `MDB_API_WORKERS`                  | 2     | 2      | 4     | gunicorn processes               |
| `MDB_HEATING_WORKERS`              | 1     | 2      | 4     | processes                        |
| `MDB_COOLING_WORKERS`              | 1     | 1      | 2     | procrastinate concurrency        |
| `MDB_ICEBERG_WORKERS`              | 2     | 4      | 8     | procrastinate concurrency        |
| `MDB_COOLING_THREADS_PER_WORKER`   | 2     | 4      | 4     | connectorx threads               |
| `MDB_DB_POOL_MAX_SIZE`             | 8     | 12     | 16    | connections per process          |
| `MDB_INGEST_WORKERS`               | 1     | 2      | 2     | processes (ingestion_queue only) |
| `MDB_INGEST_WORKERS_PER_WORKSPACE` | 1     | 1      | 1     | ingestion slots per workspace    |
| `MDB_INGEST_THREADS_PER_WORKER`    | 4     | 8      | 16    | parquet writer threads           |
| `MARPLE_API_WORKERS`               | 2     | 3      | 5     | gunicorn processes               |
| `MARPLE_PROCRASTINATE_WORKERS`     | 2     | 3      | 5     | procrastinate concurrency        |

## Per-deployment notes

The profiles are one shared manifest; each deployment flavor only uses the
variables that apply to it. Unused variables are ignored.

| Flavor             | Applies            | Profile file                         | Notes                                                                                                                                                                                             |
| ------------------ | ------------------ | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **marple-db**      | `MDB_*`, `TRINO_*` | shared `../.env.profile`             | VPC database deployment. `MARPLE_*` are ignored.                                                                                                                                                  |
| **marple-insight** | `MARPLE_*`         | shared `../.env.profile`             | VPC insight deployment. `MDB_*` / `TRINO_*` are ignored. Use the same `.env.profile` as the matching `marple-db` stack.                                                                           |
| **marple-on-prem** | all                | appended to `.env`                   | Runs the full stack; the DB API and workers are split (`marple-db` + `marple-db-worker`).                                                                                                         |
| **marple-airgap**  | all                | appended to `.env`                   | Same split layout as on-prem, without an IdP. Trino uses a minimal static config (no password auth); `TRINO_QUERY_*` from the profile are read via env substitution in `trino/config.properties`. |
