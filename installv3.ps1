param(
    [string]$Version = "v0.2.0",
    [string]$Repo = "Gggggggggbbb/syncloudAi"
)

# Set the latest stable version for Terraform
$TERRAFORM_VERSION = "1.13.3" 

Write-Output "==================================================="
Write-Output "==> Syncloud Installation Script ($Version)"
Write-Output "==================================================="
Write-Output "Installing the following components:"
Write-Output "  - 🔑 Syncloud CLI (to local AppData)"
Write-Output "  - 🌎 Terraform (version $TERRAFORM_VERSION, if missing)"
Write-Output "  - ☁️ AWS CLI (if missing)"
Write-Output ""

# ----------------------------------------------------------------------
# 2. SYNCLOUD CLI INSTALLATION (Main Binary)
# ----------------------------------------------------------------------
$installDir = "$env:LOCALAPPDATA\Programs\syncloud"
Write-Output "==> Installing Syncloud CLI to $installDir"
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

Write-Output "==> Syncloud installed successfully."
# Update PATH for the current session
$env:Path += ";$installDir"

# ----------------------------------------------------------------------
# 3. INSTALL TERRAFORM (Non-Interactive, Conditional)
# ----------------------------------------------------------------------
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Output "==> Terraform not found. Installing version $TERRAFORM_VERSION now..."
    
    # CORRECTED URL: Uses a stable version and includes version in file name
    $tfUrl = "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_windows_amd64.zip"
    $tfZip = "$env:TEMP\terraform.zip"
    $tfDir = "$env:LOCALAPPDATA\Programs\Terraform"
    
    New-Item -ItemType Directory -Force -Path $tfDir | Out-Null

    Write-Output "==> Downloading Terraform from $tfUrl"
    Invoke-WebRequest $tfUrl -OutFile $tfZip -UseBasicParsing
    
    Write-Output "==> Extracting Terraform to $tfDir"
    Expand-Archive -Path $tfZip -DestinationPath $tfDir -Force
    Remove-Item $tfZip

    # Update PATH for the current session
    $env:Path += ";$tfDir"
    
    Write-Output "Terraform installed successfully at $tfDir"
} else {
    Write-Output "Terraform already installed."
}


# ----------------------------------------------------------------------
# 4. INSTALL AWS CLI (Non-Interactive, Conditional)
# ----------------------------------------------------------------------
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Output "==> AWS CLI not found. Installing now..."
    
    $awsInstaller = "$env:TEMP\awscli.msi"
    
    Write-Output "==> Downloading AWS CLI MSI..."
    Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $awsInstaller -UseBasicParsing

    Write-Output "==> Running AWS CLI Installer (requires UAC/Admin rights for system changes)..."
    
    # Use msiexec with /qn for fully silent mode
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$awsInstaller`" /qn ALLUSERS=1"
    
    Remove-Item $awsInstaller
    Write-Output "AWS CLI installed. Run 'aws configure' to set up credentials."
} else {
    Write-Output "AWS CLI already installed."
}

# ----------------------------------------------------------------------
# 5. FINAL INSTRUCTIONS
# ----------------------------------------------------------------------
Write-Output "==================================================="
Write-Output "✅ Installation finished."
Write-Output "==================================================="
Write-Output "Note: For the new commands (syncloud, terraform, aws) to be recognized,"
Write-Output "you must **OPEN A NEW PowerShell/Command Prompt window**."
Write-Output ""
Write-Output "Run 'syncloud --help' to get started."
