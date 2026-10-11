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
