# install.ps1 — Syncloud Windows installer (robust release lookup)
# Usage:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   irm https://raw.githubusercontent.com/SyncloudAi/syncloud/main/install.ps1 | iex

param(
  [string]$Repo    = "SyncloudAi/syncloud",
  [string]$App     = "syncloud",
  [string]$Version = "latest"   # or "v0.1.0"
)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "==> $m" }
function Has($c){ $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
function IsAdmin(){
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# --- Resolve arch
switch ($env:PROCESSOR_ARCHITECTURE.ToLower()) {
  "amd64" { $ARCH="amd64" }
  "arm64" { $ARCH="arm64" }
  default { throw "Unsupported Windows arch: $($env:PROCESSOR_ARCHITECTURE)" }
}

# --- Pick install dir
$MachineDir = "C:\Program Files\$App"
$UserDir    = "$env:LOCALAPPDATA\Programs\$App"
$TargetDir  = if (IsAdmin) { $MachineDir } else { $UserDir }
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# --- Robust release/tag resolver --------------------------------------------
$Headers = @{ "User-Agent" = "$App-installer" }

function Get-ReleaseTag {
  param([string]$Repo, [string]$Version)
  if ($Version -ne "latest") { return $Version }

  # Try API first with a User-Agent
  try {
    $api = "https://api.github.com/repos/$Repo/releases/latest"
    $resp = Invoke-RestMethod -Uri $api -Headers $Headers -UseBasicParsing
    if ($resp.tag_name) { return $resp.tag_name }
  } catch {
    # ignore and try fallback
  }

  # Fallback: follow the /releases/latest redirect to extract the tag
  try {
    $url = "https://github.com/$Repo/releases/latest"
    $r = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue
    # GitHub returns a 302 with Location: .../tag/vX.Y.Z
    $loc = $r.Headers["Location"]
    if (-not $loc) {
      # sometimes Invoke-WebRequest auto-follows; take the final URL
      $loc = $r.BaseResponse.ResponseUri.AbsoluteUri
    }
    if ($loc -match "/tag/(?<tag>v[\w\.\-]+)$") { return $Matches['tag'] }
  } catch {
    # final fallback below
  }

  throw "Failed to fetch version info for $Repo."
}

$Tag = Get-ReleaseTag -Repo $Repo -Version $Version
Say "Using tag: $Tag"

# --- Download asset
$assetName = "${App}_${Tag}_windows_${ARCH}.zip"
$assetUrl  = "https://github.com/$Repo/releases/download/$Tag/$assetName"

$zip = Join-Path $env:TEMP $assetName
Say "Downloading $assetUrl"
Invoke-WebRequest -Uri $assetUrl -OutFile $zip -UseBasicParsing

Say "Extracting to $TargetDir"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $TargetDir, $true)

# --- Ensure PATH
$Scope = if (IsAdmin) { "Machine" } else { "User" }
$path  = [Environment]::GetEnvironmentVariable("Path", $Scope)
if ($path -notmatch [Regex]::Escape($TargetDir)) {
  Say "Adding $TargetDir to $Scope PATH"
  [Environment]::SetEnvironmentVariable("Path", "$path;$TargetDir", $Scope)
}

# --- Dependencies ------------------------------------------------------------
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

# --- Prompt for AWS credentials if not configured
$needsCfg = $false
try { aws sts get-caller-identity | Out-Null } catch { $needsCfg = $true }
if ($needsCfg) {
  Write-Host "`nPlease run:  aws configure"
}

Write-Host "`n✔ Installed: $TargetDir\$App.exe"
Write-Host "Open a NEW PowerShell window (PATH refresh) and run:  $App --help"
