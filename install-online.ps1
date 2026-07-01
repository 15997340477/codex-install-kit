param(
    [Parameter(Mandatory = $true)]
    [string]$PackageUrl,

    [string]$BaseUrl = "https://nexus.1982video.cn",
    [string]$Model = "gpt-5.5",
    [switch]$SkipWingetInstall
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

Write-Host "Codex online installer" -ForegroundColor Green
Write-Host "Package URL: $PackageUrl"
Write-Host "Proxy base URL: $BaseUrl"
Write-Host "Model: $Model"

Write-Step "Choosing a work directory"
$workRoot = Join-Path $env:TEMP "CodexInstallKit"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$downloadPath = Join-Path $workRoot "codex-install-kit-$stamp.zip"
$extractPath = Join-Path $workRoot "codex-install-kit-$stamp"
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
Write-Host "Work directory: $workRoot"

Write-Step "Downloading install kit"
Invoke-WebRequest -Uri $PackageUrl -OutFile $downloadPath -UseBasicParsing
Write-Host "Downloaded: $downloadPath"

Write-Step "Extracting install kit"
Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath -Force
$installer = Get-ChildItem -LiteralPath $extractPath -Recurse -Filter "Install-Codex-For-Friend.ps1" |
    Select-Object -First 1

if (-not $installer) {
    throw "Install-Codex-For-Friend.ps1 was not found in the install kit."
}

Write-Step "Running local installer"
& $installer.FullName -BaseUrl $BaseUrl -Model $Model -SkipWingetInstall:$SkipWingetInstall

Write-Step "Online install finished"
Write-Host "Downloaded files are kept in: $workRoot"
