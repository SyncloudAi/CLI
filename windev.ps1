param(
    [string]$Version = "dev0.4.7",
    [string]$Repo = "SyncloudAi/CLI"
)

# Set the latest stable version for Terraform
$TERRAFORM_VERSION = "1.13.3" 

# --- Function to Safely Update User PATH Permanently ---
function Update-UserPath {
    param(
        [Parameter(Mandatory=$true)][string]$NewPath
    )
    
    # Get the current permanent User PATH from the Windows Registry
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    # Check if the path already exists to prevent adding duplicates
    # We use a regex match on a split string to check for exact path matches
    $PathArray = $CurrentPath -split ';' | Where-Object { $_ -ne '' }
    if (-not ($PathArray | Select-String -Pattern ([regex]::Escape($NewPath)) -Quiet)) {
        
        # Add the new path to the list and join with semicolons
        $UpdatedPath = ($PathArray + $NewPath) -join ';'
        
        # Write the new PATH back to the Windows Registry (User scope)
        [Environment]::SetEnvironmentVariable("Path", $UpdatedPath, "User")
        Write-Output "==> Added $NewPath to the permanent User PATH."
    } else {
        Write-Output "==> Path $NewPath already exists in the permanent User PATH. No change made."
    }
}
# ---------------------------------------------

Write-Output "==================================================="
Write-Output "==> Syndev Installation Script ($Version)"
Write-Output "==================================================="
Write-Output "Installing the following components:"
Write-Output "  - 🔑 Syndev CLI (to local AppData)"
Write-Output "  - 🌎 Terraform (version $TERRAFORM_VERSION, if missing)"
Write-Output "  - ☁️ AWS CLI (if missing)"
Write-Output ""

# ----------------------------------------------------------------------
# 2. Syndev CLI INSTALLATION (Main Binary)
# ----------------------------------------------------------------------
$installDir = "$env:LOCALAPPDATA\Programs\syncloud"
Write-Output "==> Installing Syndev CLI to $installDir"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Detect OS/Arch
$os = "windows"
$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
$asset = "syndev_${Version}_${os}_${arch}.zip"
$url = "https://github.com/$Repo/releases/download/$Version/$asset"

Write-Output "==> Downloading Syndev CLI from Syncloud.AI"
$zipFile = "$env:TEMP\$asset"
Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force
Remove-Item $zipFile

Write-Output "==> Syndev installed successfully."

# Update PATH permanently
Update-UserPath $installDir

# ----------------------------------------------------------------------
# 3. INSTALL TERRAFORM (Non-Interactive, Conditional)
# ----------------------------------------------------------------------
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Output "==> Terraform not found. Installing version $TERRAFORM_VERSION now..."
    
    # CORRECTED URL
    $tfUrl = "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_windows_amd64.zip"
    $tfZip = "$env:TEMP\terraform.zip"
    $tfDir = "$env:LOCALAPPDATA\Programs\Terraform"
    
    New-Item -ItemType Directory -Force -Path $tfDir | Out-Null

    Write-Output "==> Downloading Terraform from $tfUrl"
    Invoke-WebRequest $tfUrl -OutFile $tfZip -UseBasicParsing
    
    Write-Output "==> Extracting Terraform to $tfDir"
    Expand-Archive -Path $tfZip -DestinationPath $tfDir -Force
    Remove-Item $tfZip

    # Update PATH permanently
    Update-UserPath $tfDir
    
    Write-Output "Terraform installed successfully."
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

    Write-Output "==> Running AWS CLI Installer (Note: This may prompt for UAC/Admin approval)..."
    
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
Write-Output "The commands are now saved permanently in your Windows PATH."
Write-Output ""
Write-Output "⚠️ IMPORTANT: For the new commands to be available, you must:"
Write-Output "  - **CLOSE ALL existing terminal windows** (PowerShell, Command Prompt, VS Code, etc.)."
Write-Output "  - **OPEN A NEW terminal window.**"
Write-Output ""
Write-Output "Once complete, run 'Syndev --help' to get started."
