param(
    [string]$Version = "v0.2.0",
    [string]$Repo = "Gggggggggbbb/syncloudAi"
)

Write-Output "==> Installing Syncloud CLI ($Version) from $Repo"

# Where to install Syncloud
$installDir = "$env:LOCALAPPDATA\Programs\syncloud"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Detect OS/Arch
$os = "windows"
$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
$asset = "syncloud_${Version}_${os}_${arch}.zip"
$url = "https://github.com/$Repo/releases/download/$Version/$asset"

Write-Output "==> Downloading Syncloud CLI from $url"
$zipFile = "$env:TEMP\$asset"
Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force
Remove-Item $zipFile

Write-Output "==> Syncloud installed at $installDir"
$env:Path += ";$installDir"

# --- Terraform ---
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Output "⚠️ Terraform not found."
    $resp = Read-Host "Do you want to install Terraform now? (y/n)"
    if ($resp -eq "y") {
        $tfUrl = "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_windows_amd64.zip"
        $tfZip = "$env:TEMP\terraform.zip"
        $tfDir = "$env:LOCALAPPDATA\Programs\Terraform"

        Write-Output "==> Downloading Terraform from $tfUrl"
        Invoke-WebRequest $tfUrl -OutFile $tfZip
        Expand-Archive $tfZip -DestinationPath $tfDir -Force
        Remove-Item $tfZip
        $env:Path += ";$tfDir"
        Write-Output "Terraform installed at $tfDir"
    } else {
        Write-Output "Skipped Terraform installation."
    }
} else {
    Write-Output "Terraform already installed."
}

# --- AWS CLI ---
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Output "⚠️ AWS CLI not found."
    $resp = Read-Host "Do you want to install AWS CLI now? (y/n)"
    if ($resp -eq "y") {
        $awsInstaller = "$env:TEMP\awscli.msi"
        Write-Output "==> Downloading AWS CLI..."
        Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $awsInstaller
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$awsInstaller`" /quiet"
        Remove-Item $awsInstaller
        Write-Output "AWS CLI installed. Run 'aws configure' to set up credentials."
    } else {
        Write-Output "Skipped AWS CLI installation."
    }
} else {
    Write-Output "AWS CLI already installed."
}

Write-Output "✅ Installation finished. Run 'syncloud --help' to get started."

