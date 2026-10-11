$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$composeFile = Join-Path $repositoryRoot "compose.production.yml"
$environmentFile = if ($env:FITNESS_ENV_FILE) {
    $env:FITNESS_ENV_FILE
} else {
    "C:\ProgramData\FitnessApp\production.env"
}

& docker compose `
    --project-directory $repositoryRoot `
    --env-file $environmentFile `
    -f $composeFile `
    run --rm -e BACKUP_KIND=daily backup

if ($LASTEXITCODE -ne 0) {
    throw "Daily database backup failed with exit code $LASTEXITCODE"
}
