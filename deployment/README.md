# Production Deployment

The production stack runs PostgreSQL, the Rails API, and a Caddy container that
serves the compiled React application and proxies API requests. Only Caddy is
published to the host, and it listens on loopback so Tailscale Serve can expose
it privately over HTTPS.

## Environment

Keep the populated environment file outside the repository. The planned Windows
location is:

```text
C:\ProgramData\FitnessApp\production.env
```

Use `deployment/production.env.example` as the list of required values. Generate
the Rails secret locally with `api/bin/rails secret`. Never commit the populated
file, credentials, certificates, API tokens, or database backups.

## Local verification

Create a temporary environment file outside the checkout, then run:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml build
docker compose --env-file /path/to/production.env -f compose.production.yml up -d
curl --fail http://127.0.0.1:8080/health
```

The API and PostgreSQL do not publish host ports. The `/health` response is only
successful when Rails can connect to PostgreSQL.

Stop the stack without deleting its database volume:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml down
```

Do not add `--volumes` when stopping a production or recovery stack.

## Private HTTPS

The Windows host will use persistent Tailscale Serve configuration to terminate
private HTTPS and proxy to `http://127.0.0.1:8080`. Tailscale, Caddy, Rails, and
PostgreSQL remain separate layers: Tailscale controls private network access and
TLS, Caddy routes web and API traffic, and Rails still requires application
authentication.

## Backups

`FITNESS_BACKUP_DIRECTORY` must point to a host directory outside the repository
and outside the Docker volume. The default Windows location is:

```text
C:\ProgramData\FitnessApp\backups
```

Create the directory before running a backup. The maintenance container writes a
full PostgreSQL custom-format dump, restores the complete archive into a
disposable database, and only then publishes the final `.dump` file.

Create a daily backup:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml run --rm -e BACKUP_KIND=daily backup
```

Create a pre-deploy backup:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml run --rm -e BACKUP_KIND=pre-deploy backup
```

Daily and pre-deploy backups have separate retention limits. The defaults retain
14 daily backups and 10 recent deployment backups. The Windows host should run
`deployment/scripts/backup.ps1` once per day from Task Scheduler under the same
Windows account that runs Docker Desktop. A failed script exits nonzero so Task
Scheduler records the failure.

Keep at least one recent verified dump on the Mac or another private local disk.
Do not store dumps in Git, GitHub Actions artifacts, or a public cloud location.

## Restore rehearsal

List the backup directory and select a specific dump filename. Verification
restores the complete archive into a disposable database without changing the
application database:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml run --rm -e BACKUP_FILE=fitness-daily-20261011T120000Z.dump verify-backup
```

Stop application traffic, restore the selected dump, and restart the stack:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml stop web api
docker compose --env-file /path/to/production.env -f compose.production.yml run --rm -e CONFIRM_RESTORE=yes -e BACKUP_FILE=fitness-daily-20261011T120000Z.dump restore
docker compose --env-file /path/to/production.env -f compose.production.yml up -d
curl --fail http://127.0.0.1:8080/health
```

Restore validates the archive first, then drops and recreates the application
database before loading it. Keep the application stopped until the command
succeeds and the database-backed health check passes.

## Manual Mac failover

Use one writable server at a time. Before promoting the Mac, shut down the
Windows stack or otherwise prevent it from returning as a writable server.

1. Copy the latest verified dump to a private backup directory on the Mac.
2. Create a populated production environment file outside the checkout. Set
   `FITNESS_BACKUP_DIRECTORY` to the Mac backup directory.
3. Start PostgreSQL with `docker compose --env-file /path/to/production.env -f compose.production.yml up -d postgres`.
4. Run the documented verify and restore commands against the selected dump.
5. Start the full stack and require `curl --fail http://127.0.0.1:8080/health` to pass.
6. Configure Tailscale Serve on the Mac and update clients to the promoted
   private URL.

When returning production to Windows, take and verify a final Mac backup, stop
the Mac stack, restore that backup on Windows, and only then make Windows
authoritative again.
