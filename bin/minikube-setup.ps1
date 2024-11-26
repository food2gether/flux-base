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

echo "Waiting for application to be ready..."
kubectl -n flux-system wait kustomization/application --for condition=ready --timeout 5m
if (-not $?) {
  echo "Something has gone wrong. Deleting cluster..."
  minikube delete
  exit 1;
} else {
  echo "Application is ready!"
}

# Remove existing DNS rules
echo "Setup DNS resolver..."
Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq "food2gether.local" } | Remove-DnsClientNrptRule -Force
# Add new DNS rule
Add-DnsClientNrptRule -Namespace "food2gether.local" -NameServer "$(minikube ip)"

if ($ApplicationComponent -ne $null) {
  echo "Patching cluster to use local deployment..."
  flux suspend $ApplicationComponent -n food2gether
  kubectl delete -k .\deployment\prod
  kubectl apply -k .\deployment\local
}

clear
echo ""
echo "Setup complete. You can now access the application at http://food2gether.local/"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
do {
  $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
} while ($key -ne "q")

minikube delete
echo "Remove DNS resolver..."
Remove-DnsClientNrptRule -Namespace "food2gether.local" -NameServer "$(minikube ip)"
