param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9a-f]{40}$")]
    [string] $CommitSha,
    [Parameter(Mandatory = $true)]
    [string] $RepositoryUrl,
    [Parameter(Mandatory = $true)]
    [string] $SourcePath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    & git @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "git failed with exit code $exitCode"
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $SourcePath ".git") -PathType Container)) {
    if (Test-Path -LiteralPath $SourcePath) {
        throw "Deployment source path exists but is not a Git checkout: $SourcePath"
    }

    Invoke-Git @("clone", $RepositoryUrl, $SourcePath)
}

Push-Location $SourcePath
try {
    $workingTreeChanges = @(& git status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect deployment checkout"
    }
    if ($workingTreeChanges.Count -gt 0) {
        throw "Deployment checkout has local changes; refusing to overwrite them"
    }

    Invoke-Git @("fetch", "--prune", "origin", "main")
    Invoke-Git @("cat-file", "-e", "$CommitSha^{commit}")

    & git merge-base --is-ancestor $CommitSha origin/main
    if ($LASTEXITCODE -ne 0) {
        throw "Requested commit is not reachable from origin/main: $CommitSha"
    }

    Invoke-Git @("checkout", "--detach", "--force", $CommitSha)
    $checkedOutCommit = (& git rev-parse "HEAD").Trim()
    if ($LASTEXITCODE -ne 0 -or $checkedOutCommit -ne $CommitSha) {
        throw "Deployment checkout does not match requested commit"
    }
} finally {
    Pop-Location
}
