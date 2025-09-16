# Syncloud Installer

This repository provides the installer scripts for the **Syncloud CLI**.  
The CLI helps DevOps teams deploy and manage infrastructure quickly with Terraform and AWS.

---

## 🚀 Install

### Windows (PowerShell)
powershell
irm https://raw.githubusercontent.com/SyncloudAi/syncloud/main/install.ps1 | iex
### macOS / Linux
curl -fsSL https://raw.githubusercontent.com/SyncloudAi/syncloud/main/install.sh | bash

## ✅ What the installer does

When you run the install command, it will:

- 🔽 **Download** the latest `syncloud` binary for your operating system and architecture from the official [GitHub Releases](https://github.com/SyncloudAi/syncloud/releases).  
- 📂 **Place it on your PATH** so you can run `syncloud` from any terminal.  
- 🔍 **Check for Terraform** — if it’s not installed, the installer will download and set it up.  
- 🔍 **Check for AWS CLI** — if it’s not installed, the installer will download and set it up.  
- 🔑 Remind you to run `aws configure` to set up your AWS credentials if they aren’t already configured.
