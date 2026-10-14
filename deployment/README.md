# Production Deployment

The reference production host is an Oracle Cloud Infrastructure Always Free
Ubuntu ARM64 VM. Docker Compose runs PostgreSQL, the Rails API, and Caddy. Caddy
serves the compiled React application and proxies API requests. Only Caddy is
published to the host, and it listens on loopback so Tailscale Serve can expose
the app privately over HTTPS.

The repository contains no production credentials or owner account. A fork uses
its own Tailscale identity, operator-owned SSH configuration, and host-local
files. GitHub Actions verifies the production build but has no access to the
production host.

## Host prerequisites

Create an Always Free-eligible `VM.Standard.A1.Flex` instance with a supported
Ubuntu LTS image. Keep Rails, PostgreSQL, port 8080, and SSH closed in the OCI
public ingress rules. The operator workstation reaches SSH through Tailscale.

Install Docker Engine with the Compose plugin, Git, curl, Tailscale, and OpenSSH
Server. Create a dedicated `fitness-app` deployment user, give it permission to
run Docker, and enable the system services:

```sh
sudo adduser --disabled-password --gecos "" fitness-app
sudo usermod --append --groups docker fitness-app
sudo systemctl enable --now docker
sudo systemctl enable --now ssh
sudo systemctl enable --now tailscaled
docker compose version
git --version
curl --version
```

Docker access is effectively root access. Do not use the deployment account for
unrelated workloads. Start a new login session after changing its group
membership.

Install the [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
as the `fitness-app` user and allow its installer to place the executable in
`/home/fitness-app/bin`. Verify it from that account with `oci --version`.

Create the host-owned configuration directories:

```sh
sudo install -d -m 750 -o fitness-app -g fitness-app /etc/fitness-app
sudo install -d -m 750 -o fitness-app -g fitness-app /srv/fitness-app
sudo install -d -m 750 -o fitness-app -g fitness-app /srv/fitness-app/backups
```

Copy `deployment/deployment.env.example` to
`/etc/fitness-app/deployment.env` and `deployment/production.env.example` to
`/etc/fitness-app/production.env`. Populate them on the host and restrict access:

```sh
sudo chown fitness-app:fitness-app /etc/fitness-app/deployment.env /etc/fitness-app/production.env
sudo chmod 600 /etc/fitness-app/deployment.env /etc/fitness-app/production.env
```

Generate `SECRET_KEY_BASE` with `api/bin/rails secret` from a local checkout and
generate a unique PostgreSQL password. Never commit the populated files,
credentials, certificates, API tokens, or database backups.

## Private HTTPS

Log the server into the operator's tailnet, assign a dedicated production tag,
and configure Tailscale Serve once:

```sh
sudo tailscale serve --bg http://127.0.0.1:8080
tailscale serve status
```

The Serve configuration and Tailscale daemon survive host restarts. Production
containers use `restart: unless-stopped`, and Docker starts through systemd.
Tailscale controls private network access and TLS; Caddy routes web and API
traffic; Rails still requires application authentication.

Configure key-only OpenSSH access for the `fitness-app` user. Put only the
operator workstation's public key in `~fitness-app/.ssh/authorized_keys`. Keep
the private key on the operator workstation. Record the server's OpenSSH host
key from a trusted connection and verify its fingerprint before adding it to the
operator workstation's known-hosts file. Do not use `ssh-keyscan` during a
deployment.

Grant only the operator's Tailscale identity access to TCP 22 on the production
device. Do not forward ports 22 or 8080 from another network, and do not add
public OCI ingress rules for them.

## Operator deployment

GitHub Actions builds and tests the production stack but never connects to the
production VM. Deploy from a trusted macOS or Linux workstation after the exact
`main` commit passes CI. The workstation must be connected to the same tailnet
as the production host and have `git`, `ssh`, and `scp` installed.

Configure a dedicated host alias in `~/.ssh/config`. Keep the hostname, private
key, and verified known-hosts entry outside the repository:

```sshconfig
Host fitness-production
  HostName replace-with-private-tailscale-hostname
  User fitness-app
  IdentityFile ~/.ssh/fitness-app-production
  IdentitiesOnly yes
  BatchMode yes
  StrictHostKeyChecking yes
  UserKnownHostsFile ~/.ssh/fitness-app-production-known-hosts
  ServerAliveInterval 15
  ServerAliveCountMax 4
```

Create the operator configuration directory:

```sh
mkdir -p ~/.config/fitness-app
chmod 700 ~/.config/fitness-app
```

Then create `~/.config/fitness-app/operator.env`. The values identify the
deployment target and public source repository; they are not application or
database credentials:

```sh
FITNESS_PRODUCTION_SSH_TARGET=fitness-production
FITNESS_DEPLOY_REPOSITORY_URL=https://github.com/replace-with-owner/fitness-app.git
```

```sh
chmod 600 ~/.config/fitness-app/operator.env
```

Application and database secrets remain in
`/etc/fitness-app/production.env` on the production host. The SSH private key
remains in the operator's standard SSH configuration. Neither belongs in GitHub
repository settings or tracked files.

After the target commit passes CI, update a local `main` checkout and deploy its
exact commit:

```sh
git switch main
git pull --ff-only
deployment_commit=$(git rev-parse HEAD)
./deployment/scripts/deploy-remote.sh "$deployment_commit"
```

The operator script fetches `origin/main` and refuses to continue unless the
requested commit is both the current checkout and the exact remote `main` tip.
It also refuses locally modified deployment scripts. It then uploads the two
host-side scripts over SSH and starts the deployment. A fork supplies its own
operator configuration and public repository URL; CI requires no production
configuration and never attempts a deployment.

On the host, the deployment script refuses a dirty managed checkout, verifies
that the exact requested commit belongs to the configured repository's
`origin/main`, builds the images, stops web and API traffic, creates a
pre-migration backup, runs Rails migrations, updates the services, and requires
the database-backed health check to pass. Failures print container state and
logs to the operator's terminal and never record a successful deployed commit.

## Local verification

Use a populated environment file outside the checkout:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml build
docker compose --env-file /path/to/production.env -f compose.production.yml up -d
curl --fail http://127.0.0.1:8080/health
```

Stop the stack without deleting its database volume:

```sh
docker compose --env-file /path/to/production.env -f compose.production.yml down
```

Do not add `--volumes` when stopping a production or recovery stack.

## Initial account

There is no public sign-up flow. After the first successful deploy, provision
the installation's owner and issue the iPhone API token on the host. Read the
password without putting it in shell history:

```sh
cd /srv/fitness-app/source
read -r -p "Email: " FITNESS_USER_EMAIL
read -r -s -p "Password: " FITNESS_USER_PASSWORD
printf '\n'
export FITNESS_USER_EMAIL FITNESS_USER_PASSWORD
docker compose --env-file /etc/fitness-app/production.env -f compose.production.yml run --rm \
  -e FITNESS_USER_EMAIL -e FITNESS_USER_PASSWORD api bin/rails fitness:provision_user
unset FITNESS_USER_PASSWORD
```

Issue the token and copy its one-time plaintext output directly into the app's
Keychain-backed configuration:

```sh
export FITNESS_API_TOKEN_NAME=iPhone
docker compose --env-file /etc/fitness-app/production.env -f compose.production.yml run --rm \
  -e FITNESS_USER_EMAIL -e FITNESS_API_TOKEN_NAME api bin/rails fitness:issue_api_token
unset FITNESS_USER_EMAIL FITNESS_API_TOKEN_NAME
```

Do not add the password or printed API token to `production.env`, Git, or GitHub.

## Backups

`FITNESS_BACKUP_DIRECTORY` points to a host directory outside the checkout and
outside the Docker volume. The maintenance container writes a full PostgreSQL
custom-format dump, restores the archive into a disposable database, and only
then publishes the final `.dump` file.

Create a daily backup:

```sh
/srv/fitness-app/source/deployment/scripts/backup.sh daily
```

Create a pre-deploy backup:

```sh
/srv/fitness-app/source/deployment/scripts/backup.sh pre-deploy
```

Daily and pre-deploy backups have separate retention limits. The defaults keep
14 daily backups and 10 recent deployment backups.

### Object Storage

Create a private OCI Object Storage bucket in the production compartment. Keep
its storage and request usage inside the Always Free allowance. Object Storage
encrypts objects at rest by default; do not make the bucket public or create a
pre-authenticated request.

Create an OCI dynamic group that matches only the production instance:

```text
instance.id = '<production-instance-ocid>'
```

Grant that dynamic group only the access needed to inspect the bucket and sync
objects. Replace every placeholder with resources owned by the installation:

```text
Allow dynamic-group <backup-dynamic-group> to read buckets in compartment <production-compartment> where target.bucket.name = '<backup-bucket>'
Allow dynamic-group <backup-dynamic-group> to {OBJECT_INSPECT, OBJECT_READ, OBJECT_CREATE} in compartment <production-compartment> where target.bucket.name = '<backup-bucket>'
```

Keep object versioning disabled; backup filenames are unique and the VM cannot
overwrite them. Object Lifecycle Management runs as the regional Object Storage
service rather than as the VM. In a policy created in the tenancy root, grant
that service only the bucket and object permissions needed to execute deletion:

```text
Allow service objectstorage-<region-identifier> to manage object-family in compartment <production-compartment> where all {target.bucket.name='<backup-bucket>', any {request.permission='BUCKET_INSPECT', request.permission='BUCKET_READ', request.permission='OBJECT_INSPECT', request.permission='OBJECT_DELETE'}}
```

Configure an enabled lifecycle rule named `fitness-app-90-day-retention` to
delete objects under the chosen backup prefix after 90 days. That keeps normal
retention comfortably beyond the local 14-day window without allowing backups
to grow beyond the free storage quota.

Set `OCI_BACKUP_NAMESPACE`, `OCI_BACKUP_BUCKET`, and `OCI_BACKUP_PREFIX` in
`/etc/fitness-app/deployment.env`. These identifiers are not credentials. The
replication script authenticates with the VM's instance principal, so no OCI API
key is stored on the host, in GitHub, or in the repository.

Test the instance principal as the deployment user:

```sh
sudo -u fitness-app OCI_CLI_AUTH=instance_principal oci os bucket get \
  --namespace-name <object-storage-namespace> \
  --bucket-name <backup-bucket>
sudo -u fitness-app OCI_CLI_AUTH=instance_principal oci os object-lifecycle-policy get \
  --namespace-name <object-storage-namespace> \
  --bucket-name <backup-bucket> \
  --query 'data.rules[].{name:name,enabled:"is-enabled",action:action,days:"time-amount"}' \
  --output table
```

Confirm the named rule reports `enabled: true`, `action: DELETE`, and `days: 90`.
OCI runs lifecycle rules daily and may take up to 24 hours to begin processing.

`replicate-backups.sh` uploads new `.dump` files as single-part objects and never
passes the OCI CLI delete option. Its instance principal cannot overwrite or
delete objects, including through multipart APIs. Local retention therefore
cannot remove the independent Object Storage copies; only the bucket's 90-day
lifecycle rule expires them.

### Daily timer

After the first deployment, install and enable the systemd units:

```sh
sudo bash -c '
  set -euo pipefail
  source /etc/fitness-app/deployment.env
  source_path=${FITNESS_DATA_ROOT:-/srv/fitness-app}/source
  install -d -m 755 /usr/local/lib/fitness-app
  install -m 755 \
    "$source_path/deployment/scripts/backup-job.sh" \
    /usr/local/lib/fitness-app/backup-job.sh
  install -m 644 \
    "$source_path/deployment/systemd/fitness-app-backup.service" \
    "$source_path/deployment/systemd/fitness-app-backup.timer" \
    /etc/systemd/system/
'
sudo systemctl daemon-reload
sudo systemctl enable --now fitness-app-backup.timer
systemctl list-timers fitness-app-backup.timer
```

The fixed launcher reads `/etc/fitness-app/deployment.env`, so a nondefault
`FITNESS_DATA_ROOT` still resolves the managed checkout correctly. After a
deployment that changes the launcher or units, reinstall those host copies.

The persistent timer runs once per day around 03:00 server time, creates and
verifies a local dump, then syncs retained dumps to Object Storage. Exercise the
complete job after setup and inspect its logs:

```sh
sudo systemctl start fitness-app-backup.service
sudo systemctl show fitness-app-backup.service --property=Result --property=ExecMainStatus
sudo journalctl --unit fitness-app-backup.service --since today
```

The oneshot service returns to an inactive state after a successful run. A
backup or replication failure makes it fail and remains visible in the systemd
journal. The next timer run retries the complete sequence.

## Restore rehearsal

List the backup directory and select a specific dump filename. Verification
restores the complete archive into a disposable database without changing the
application database:

```sh
cd /srv/fitness-app/source
docker compose --env-file /etc/fitness-app/production.env -f compose.production.yml run --rm \
  -e BACKUP_FILE=fitness-daily-20261011T120000Z.dump verify-backup
```

Stop application traffic, restore the selected dump, and restart the stack:

```sh
docker compose --env-file /etc/fitness-app/production.env -f compose.production.yml stop web api
docker compose --env-file /etc/fitness-app/production.env -f compose.production.yml run --rm \
  -e CONFIRM_RESTORE=yes -e BACKUP_FILE=fitness-daily-20261011T120000Z.dump restore
docker compose --env-file /etc/fitness-app/production.env -f compose.production.yml up -d
curl --fail http://127.0.0.1:8080/health
```

Restore validates the archive first, then drops and recreates the application
database before loading it. Keep the application stopped until the command
succeeds and the database-backed health check passes.

If the VM-local copy is unavailable, download the selected object through an
authenticated OCI Console session or sync it to a replacement OCI host with an
authorized instance principal:

```sh
oci os object sync \
  --auth instance_principal \
  --namespace-name <object-storage-namespace> \
  --bucket-name <backup-bucket> \
  --prefix production/ \
  --dest-dir /srv/fitness-app/backups \
  --include '*.dump'
```

Periodically download at least one recent verified dump to a private disk on the
Mac. This off-tenancy copy is the recovery source if the OCI tenancy or bucket is
unavailable. Do not place dumps in Git, GitHub Actions artifacts, or public
storage.

## Manual Mac failover

Use one writable server at a time. Before promoting the Mac, stop the OCI stack
or otherwise prevent it from returning as a writable server.

1. Obtain the latest verified dump on the Mac.
2. Create a populated production environment file outside the checkout and set
   `FITNESS_BACKUP_DIRECTORY` to the Mac backup directory.
3. Start PostgreSQL with `docker compose --env-file /path/to/production.env -f compose.production.yml up -d postgres`.
4. Run the documented verify and restore commands against the selected dump.
5. Start the full stack and require `curl --fail http://127.0.0.1:8080/health` to pass.
6. Configure Tailscale Serve on the Mac and point clients to the promoted private URL.

When returning production to OCI, take and verify a final Mac backup, stop the
Mac stack, restore that backup on OCI, and only then make OCI authoritative.
