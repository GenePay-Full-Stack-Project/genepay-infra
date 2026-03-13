# push-to-dockerhub.ps1
# Script to build and push GenePay images to Docker Hub

param (
    [Parameter(Mandatory=$true)]
    [string]$DockerHubUsername,
    
    [string]$Tag = "latest"
)

Write-Host "=========================================================="
Write-Host "GenePay Docker Hub Push Script"
Write-Host "Pushing to namespace: $DockerHubUsername with tag: $Tag"
Write-Host "=========================================================="
Write-Host "Ensure you are logged in first by running: docker login"
Write-Host "=========================================================="

# Define the service paths and image names
$Services = @(
    @{ Name = "genepay-biometric-service"; Path = "..\..\..\modules\genepay-biometric-service" },
    @{ Name = "genepay-blockchain-service"; Path = "..\..\..\modules\genepay-blockchain-service\relay" },
    @{ Name = "genepay-payment-service"; Path = "..\..\..\modules\genepay-payment-service" },
    @{ Name = "genepay-admin-dashboard"; Path = "..\..\..\web\genepay-admin-dashboard" },
    @{ Name = "genepay-blockchain-dashboard"; Path = "..\..\..\web\genepay-blockchain-dashboard" }
)

# Move to the script's directory so relative paths work reliably
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

foreach ($Service in $Services) {
    if (-not (Test-Path $Service.Path)) {
        Write-Warning "Directory not found: $($Service.Path). Make sure you run this script from its original location."
        continue
    }

    $ImageName = "${DockerHubUsername}/$($Service.Name):${Tag}"
    
    Write-Host "`n>>> Building ${ImageName}..." -ForegroundColor Cyan
    Set-Location $Service.Path
    
    # Run the docker build command
    docker build -t $ImageName .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build $($Service.Name)."
        Set-Location $ScriptDir
        continue
    }
    
    Write-Host ">>> Pushing ${ImageName}..." -ForegroundColor Cyan
    docker push $ImageName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push $($Service.Name)."
    } else {
        Write-Host ">>> Successfully pushed ${ImageName}" -ForegroundColor Green
    }
    
    Set-Location $ScriptDir
}

Write-Host "`n=========================================================="
Write-Host "All builds and pushes completed."
Write-Host "=========================================================="
Write-Host "Don't forget to update your Kubernetes deployment files in k8s/"
Write-Host "to use ${DockerHubUsername}/<image_name>:${Tag} instead of 'YOUR_ECR_URI/...'"
Write-Host "=========================================================="
