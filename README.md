🚀 Quick Start

Install Syncloud CLI in one line:

🪟 Windows (PowerShell)
Set-ExecutionPolicy Bypass -Scope Process -Force

irm get.syncloud.ai | iex

🍎 macOS / 🐧 Linux

curl -fsSL get.syncloud.ai/sh | bash

***If Terraform or AWS CLI are not installed, the installer will prompt you to install them automatically.***

🔒 Security Note

The PowerShell command changes execution policy only for the current session:

Set-ExecutionPolicy Bypass -Scope Process -Force
Restores automatically when you close PowerShell.
Does not weaken global system security!.

✅ What the installer does

When you run the installer:

Downloads and installs Syncloud CLI (to C:\Users\<You>\AppData\Local\Programs\syncloud on Windows, or ~/.local/bin on macOS/Linux).

Adds Syncloud CLI to your PATH so you can run it globally as syncloud.

Checks dependencies:

🔎 If Terraform is missing → you’ll be prompted if you want it installed automatically.

🔎 If AWS CLI is missing → you’ll be prompted if you want it installed automatically.

✅ If both are already installed → nothing is changed.

Reminds you to run:

aws configure


to set up your AWS credentials.

🛠️ Usage

After installation, run:

syncloud --help


You’ll see available commands:

create-plan → Create a new infrastructure deployment plan

update-plan → Create an update plan for existing infrastructure

execute-create → Execute a previously created deployment plan

execute-update → Execute a previously created update plan

heal → Run healing on existing Terraform infrastructure

explain → Get explanations & guidance about your infra

📋 Requirements

Windows 10/11 with PowerShell 5+ or PowerShell 7+

macOS (Intel or Apple Silicon) or Linux (x86_64, ARM64)

Internet connection

AWS account & credentials (aws configure)


If Terraform or AWS CLI are not installed, the installer will prompt you to install them automatically.


