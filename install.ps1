# install.ps1 — Syncloud Windows installer (PS 5.1 compatible)
# Usage (as user or admin):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   irm https://raw.githubusercontent.com/SyncloudAi/syncloud/main/install.ps1 | iex
param(
  [string]$Repo    = "SyncloudAi/syncloud",
  [string]$App     = "syncloud",
  [string]$Version = "latest"           # or "v0.1.0"
)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "==> $m" }
function Has($c){ $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
function IsAdmin(){
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Detect arch
$arch = $env:PROCESSOR_ARCHITECTURE.ToLower()
switch ($arch) {
  "amd64" { $ARCH="amd64" }
  "arm64" { $ARCH="arm64" }
  default { throw "Unsupported Windows arch: $arch" }
}

# Pick install dir
$MachineDir = "C:\Program Files\$App"
$UserDir    = "$env:LOCALAPPDATA\Programs\$App"
$TargetDir  = if (IsAdmin) { $MachineDir } else { $UserDir }
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# Resolve release asset
if ($Version -eq "latest") {
  $api = "https://api.github.com/repos/$Repo/releases/latest"
} else {
  $api = "https://api.github.com/repos/$Repo/releases/tags/$Version"
}
Say "Fetching release metadata: $api"
$release = Invoke-RestMethod -Uri $api -UseBasicParsing
$want = "$App" + "_" + ($release.tag_name) + "_windows_" + $ARCH + ".zip"
$asset = $release.assets | Where-Object { $_.name -eq $want }
if (-not $asset) { throw "Release asset not found: $want" }

# Download & extract
$zip = Join-Path $env:TEMP $asset.name
Say "Downloading $($asset.browser_download_url)"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing

Say "Extracting to $TargetDir"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $TargetDir, $true)

# Ensure PATH
$Scope = if (IsAdmin) { "Machine" } else { "User" }
$path  = [Environment]::GetEnvironmentVariable("Path", $Scope)
if ($path -notmatch [Regex]::Escape($TargetDir)) {
  Say "Adding $TargetDir to $Scope PATH"
  [Environment]::SetEnvironmentVariable("Path", "$path;$TargetDir", $Scope)
}

# ----- Dependencies -----
function Ensure-Terraform {
  if (Has terraform) { Say "Terraform present: $(terraform version | Select-Object -First 1)"; return }
  Say "Terraform missing: installing…"
  if (Has winget) {
    winget install --id HashiCorp.Terraform -e --accept-package-agreements --accept-source-agreements
    return
  } elseif (Has choco) {
    choco install -y terraform
    return
  }
  $tfVer = "1.9.5"
  $tfZip = Join-Path $env:TEMP "terraform_${tfVer}_windows_${ARCH}.zip"
  $tfUrl = "https://releases.hashicorp.com/terraform/$tfVer/terraform_${tfVer}_windows_${ARCH}.zip"
  Say "Downloading Terraform $tfVer"
  Invoke-WebRequest -Uri $tfUrl -OutFile $tfZip -UseBasicParsing
  [System.IO.Compression.ZipFile]::ExtractToDirectory($tfZip, $TargetDir, $true)
}

function Ensure-AwsCli {
  if (Has aws) { Say "AWS CLI present: $(aws --version)"; return }
  Say "AWS CLI missing: installing…"
  if (Has winget) {
    winget install --id Amazon.AWSCLI -e --accept-package-agreements --accept-source-agreements
    return
  } elseif (Has choco) {
    choco install -y awscli
    return
  }
  $msi = Join-Path $env:TEMP "AWSCLIV2.msi"
  $url = "https://awscli.amazonaws.com/AWSCLIV2.msi"
  Say "Downloading AWS CLI MSI"
  Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
  Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait -NoNewWindow
}

Ensure-Terraform
Ensure-AwsCli

# Prompt to configure AWS if no identity
$needConfig = $false
try { aws sts get-caller-identity | Out-Null } catch { $needConfig = $true }
if ($needConfig) {
  Write-Host "`nPlease run:  aws configure"
}

Write-Host "`n✔ Installed: $TargetDir\$App.exe"
Write-Host "Open a NEW PowerShell window (PATH refresh) and run:  $App --help"
