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

On Windows, enable Tailscale unattended mode and configure Serve once:

```powershell
tailscale serve --bg http://127.0.0.1:8080
tailscale serve status
```

The background Serve configuration survives Tailscale and host restarts. Docker
Desktop must start when the production Windows account signs in; every long-lived
container uses `restart: unless-stopped`. Test the complete startup path after a
Windows reboot before treating the host as production.

## Windows host

The deployment checkout is managed at
`C:\ProgramData\FitnessApp\source`. Do not edit files there manually. Create
`C:\ProgramData\FitnessApp\production.env` from the committed example and create
the backup directory before the first deploy. The populated environment file,
database volume, and backups never leave the host during deployment.

Install and configure Windows OpenSSH Server for key-only access by a dedicated
deployment account. That account needs permission to run Docker and write to
`C:\ProgramData\FitnessApp`, but it does not need a GitHub credential because the
repository is public. Restrict the Windows firewall rule for TCP 22 to the
Tailscale interface or Tailscale address ranges. Do not forward port 22 or 8080
from the router.

Use a dedicated SSH key pair for deployment. Put only the public key in the
deployment account's `authorized_keys`. Record the Windows OpenSSH host key from
a trusted local connection and compare its fingerprint with the host's
`C:\ProgramData\ssh\ssh_host_ed25519_key.pub` before storing it in GitHub. The
workflow uses strict host checking and never calls `ssh-keyscan` during a deploy.

## GitHub deployment

This public repository must not use a persistent self-hosted runner on the
production machine. The deploy job uses an ephemeral GitHub-hosted runner,
authenticates to Tailscale with GitHub OIDC, and reaches Windows through standard
OpenSSH over the tailnet.

Create a GitHub environment named `production` and limit its deployment branch
to protected `main`. Configure these environment variables:

```text
TAILSCALE_OIDC_CLIENT_ID
TAILSCALE_OIDC_AUDIENCE
PRODUCTION_SSH_HOST
PRODUCTION_SSH_USER
```

Configure these environment secrets:

```text
PRODUCTION_SSH_PRIVATE_KEY
PRODUCTION_SSH_KNOWN_HOSTS
```

The known-hosts value is public key material, but keeping it in the environment
also avoids publishing the private tailnet hostname. The SSH private key is the
only long-lived deployment credential in GitHub. Application secrets remain in
the host-local production environment file.

In Tailscale, create a GitHub OIDC federated identity with `auth_keys` write
scope and permission to issue `tag:github-deploy`. This repository uses GitHub's
immutable OIDC subject format:

```text
repo:jonton11@10856948/fitness-app@1398605359:environment:production
```

Grant `tag:github-deploy` access only to TCP 22 on the Windows production device,
which should have a separate production tag. Store the generated Tailscale
client ID and audience as the GitHub environment variables above; neither value
is a secret.

Finally, create the repository variable below only after the host, tailnet ACL,
SSH key, environment file, and backup directory are ready:

```text
PRODUCTION_DEPLOY_ENABLED=true
```

Every push to `main` then deploys only after Rails, web, iOS, and Compose checks
pass. A manual run of the CI workflow on `main` follows the same checks and can
be used for the initial deploy or a retry.

The deployment script refuses a dirty managed checkout, verifies that the exact
requested commit belongs to `origin/main`, builds images, stops web and API
traffic, creates a pre-migration backup, runs Rails migrations, updates the
services, and requires the database-backed health endpoint to pass. Failures
print container state and logs and do not report a successful deployed commit.
Once application traffic has been stopped, a failed backup or migration leaves
it stopped so an operator can retry or restore without accepting new writes.

## Initial account

There is no public sign-up flow. After the first successful deploy, run the
existing Rails tasks on the Windows host to provision the single user and issue
the iPhone API token. Read the password without putting it in shell history:

```powershell
Set-Location C:\ProgramData\FitnessApp\source
$env:FITNESS_USER_EMAIL = Read-Host "Email"
$securePassword = Read-Host "Password" -AsSecureString
$env:FITNESS_USER_PASSWORD = [System.Net.NetworkCredential]::new("", $securePassword).Password
docker compose --env-file C:\ProgramData\FitnessApp\production.env -f compose.production.yml run --rm -e FITNESS_USER_EMAIL -e FITNESS_USER_PASSWORD api bin/rails fitness:provision_user
Remove-Item Env:FITNESS_USER_PASSWORD
```

Issue the iPhone token and copy its one-time plaintext output directly into the
app's Keychain-backed configuration:

```powershell
$env:FITNESS_API_TOKEN_NAME = "iPhone"
docker compose --env-file C:\ProgramData\FitnessApp\production.env -f compose.production.yml run --rm -e FITNESS_USER_EMAIL -e FITNESS_API_TOKEN_NAME api bin/rails fitness:issue_api_token
Remove-Item Env:FITNESS_USER_EMAIL
Remove-Item Env:FITNESS_API_TOKEN_NAME
```

Do not add the password or printed API token to `production.env`, Git, or GitHub.

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
