param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9a-f]{40}$")]
    [string] $CommitSha
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$dataRoot = "C:\ProgramData\FitnessApp"
$sourcePath = Join-Path $dataRoot "source"
$environmentFile = Join-Path $dataRoot "production.env"
$backupDirectory = Join-Path $dataRoot "backups"
$deployedCommitFile = Join-Path $dataRoot "deployed-commit.txt"
$repositoryUrl = "https://github.com/jonton11/fitness-app.git"
$previousLocation = Get-Location
$composeArguments = $null
$deploymentStarted = $false

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    & $Command @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Command failed with exit code $exitCode"
    }
}

function Invoke-ExternalOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $output = @(& $Command @Arguments)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Command failed with exit code $exitCode"
    }

    return $output
}

try {
    if (-not (Test-Path -LiteralPath $environmentFile -PathType Leaf)) {
        throw "Production environment file not found: $environmentFile"
    }

    New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null

    & (Join-Path $PSScriptRoot "checkout.ps1") `
        -CommitSha $CommitSha `
        -RepositoryUrl $repositoryUrl `
        -SourcePath $sourcePath
    Set-Location $sourcePath

    $composeFile = Join-Path $sourcePath "compose.production.yml"
    $composeArguments = @("compose", "--env-file", $environmentFile, "-f", $composeFile)
    $deploymentStarted = $true

    Invoke-External "docker" ($composeArguments + @("config", "--quiet"))
    Invoke-External "docker" ($composeArguments + @("build", "api", "web"))
    Invoke-External "docker" ($composeArguments + @("up", "-d", "postgres"))
    Invoke-External "docker" ($composeArguments + @("stop", "web", "api"))
    Invoke-External "docker" ($composeArguments + @("run", "--rm", "-e", "BACKUP_KIND=pre-deploy", "backup"))
    Invoke-External "docker" ($composeArguments + @("run", "--rm", "api", "bin/rails", "db:migrate"))
    Invoke-External "docker" ($composeArguments + @("up", "-d", "--wait", "--remove-orphans"))

    $publishedAddress = @(Invoke-ExternalOutput "docker" ($composeArguments + @("port", "web", "8080")))
    if ($publishedAddress.Count -eq 0) {
        throw "Unable to determine the production health-check port"
    }

    $publishedPort = ($publishedAddress[0].Trim() -split ":")[-1]
    if ($publishedPort -notmatch "^\d+$") {
        throw "Unexpected published address: $($publishedAddress[0])"
    }

    $healthUri = "http://127.0.0.1:$publishedPort/health"
    $healthy = $false
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $healthUri -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                $healthy = $true
                break
            }
        } catch {
            if ($attempt -eq 12) {
                break
            }
        }

        Start-Sleep -Seconds 5
    }

    if (-not $healthy) {
        throw "Production health check failed: $healthUri"
    }

    Set-Content -LiteralPath $deployedCommitFile -Value $CommitSha -Encoding ascii
    Write-Output "Deployed $CommitSha"
} catch {
    if ($deploymentStarted) {
        $statusArguments = $composeArguments + @("ps")
        $logArguments = $composeArguments + @("logs", "--tail", "200", "api", "web", "postgres")
        & docker @statusArguments
        & docker @logArguments
    }
    throw
} finally {
    Set-Location $previousLocation
}
