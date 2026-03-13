# port-forward.ps1
# PowerShell script to start port forwarding for all GenePay services

Write-Host "=========================================================="
Write-Host "Starting port forwarding for GenePay services..."
Write-Host "=========================================================="

# Remove previous jobs if they exist
Get-Job -Name "PortForward-*" -ErrorAction SilentlyContinue | Remove-Job -Force

# We use Start-Job to run the kubectl port-forward processes in the background
Start-Job -Name "PortForward-PG" -ScriptBlock { kubectl port-forward -n genepay svc/postgres 5432:5432 }
Start-Job -Name "PortForward-Bio" -ScriptBlock { kubectl port-forward -n genepay svc/biometric-service 8001:8001 }
Start-Job -Name "PortForward-Relay" -ScriptBlock { kubectl port-forward -n genepay svc/blockchain-relay 3001:3001 }
Start-Job -Name "PortForward-Payment" -ScriptBlock { kubectl port-forward -n genepay svc/payment-service 8080:8080 }
# Mapping frontend dashboards to their standard docker-compose local ports (3000 & 3002)
Start-Job -Name "PortForward-Admin" -ScriptBlock { kubectl port-forward -n genepay svc/admin-dashboard 3000:80 }
Start-Job -Name "PortForward-BlockDB" -ScriptBlock { kubectl port-forward -n genepay svc/blockchain-dashboard 3002:80 }

Start-Sleep -Seconds 3

Write-Host "Port forwarding jobs started in the background."
Write-Host "PostgreSQL:           http://localhost:5432"
Write-Host "Biometric Service:    http://localhost:8001"
Write-Host "Blockchain Relay:     http://localhost:3001"
Write-Host "Payment Service:      http://localhost:8080"
Write-Host "Admin Dashboard:      http://localhost:3000"
Write-Host "Blockchain Dashboard: http://localhost:3002"
Write-Host "=========================================================="
Write-Host "To view logs from the forwarding: Get-Job -Name 'PortForward-*' | Receive-Job"
Write-Host "To stop forwarding, run:          Get-Job -Name 'PortForward-*' | Remove-Job -Force"
Write-Host "=========================================================="
