# Set the error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

function FailGate {
  if (-not $?) {
    Write-Host "Failed to execute the command. Exiting..."
    exit 1
  }
}

# Install Minikube & bootstrap flux
Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content .\bin\minikube-setup)))

# Remove existing DNS rules
Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq "food2gether.local" } | Remove-DnsClientNrptRule -Force
# Add new DNS rule
Add-DnsClientNrptRule -Namespace "food2gether.local" -NameServer "$(minikube ip)"

