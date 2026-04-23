param (
    [string]$AwsAccountId = "357343207025",
    [string]$Region = "ap-southeast-1"
)

$RegistryUrl = "$AwsAccountId.dkr.ecr.${Region}.amazonaws.com"

Write-Host "Logging into ECR $RegistryUrl..."
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $RegistryUrl

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to ECR. Please ensure AWS CLI is configured correctly."
    exit 1
}

# Paths are relative to infra/genepay-infra/scripts
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = (Get-Item "$ScriptDir\..\..\..").FullName

$Services = @(
    @{ Name="genepay-admin-dashboard"; Path="web\genepay-admin-dashboard" },
    @{ Name="genepay-biometric-service"; Path="modules\genepay-biometric-service" },
    @{ Name="genepay-blockchain-dashboard"; Path="web\genepay-blockchain-dashboard" },
    @{ Name="genepay-blockchain-service"; Path="modules\genepay-blockchain-service\relay" },
    @{ Name="genepay-payment-service"; Path="modules\genepay-payment-service" }
)

foreach ($Service in $Services) {
    $ImageName = $Service.Name
    $ServicePath = Join-Path $RootDir $Service.Path
    $FullImageName = "$RegistryUrl/${ImageName}:latest"

    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Building $ImageName..." -ForegroundColor Green
    docker build -t $FullImageName $ServicePath

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build $ImageName"
        exit $LASTEXITCODE
    }

    Write-Host "Pushing $ImageName to ECR..." -ForegroundColor Green
    docker push $FullImageName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push $ImageName"
        exit $LASTEXITCODE
    }
}

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "All images built and pushed to ECR successfully!" -ForegroundColor Green
