#Requires -RunAsAdministrator

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
Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Invoke-WebRequest https://raw.githubusercontent.com/food2gether/flux-base/refs/heads/main/bin/minikube-setup).Content))

# Remove existing DNS rules
Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq "food2gether.local" } | Remove-DnsClientNrptRule -Force
# Add new DNS rule
Add-DnsClientNrptRule -Namespace "food2gether.local" -NameServer "$(minikube ip)"

if ($ApplicationComponent -ne $null) {
  echo "Patching cluster to use local deployment..."
  flux suspend $ApplicationComponent -n food2gether
  kubectl delete -k .\deployment\prod
  kubectl apply -k .\deployment\local
}

echo "Setup complete. You can now access the application at http://food2gether.local/"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
do {
  $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
} while ($key -ne "q")

minikube delete
Remove-DnsClientNrptRule -Namespace "food2gether.local" -NameServer "$(minikube ip)"
