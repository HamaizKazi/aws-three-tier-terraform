
param(
    [string]$ProjectName = "aws-terraform",
    [string]$Profile = "aws-learning",
    [string]$Region = "ap-southeast-2"
)

$ErrorActionPreference = "Stop"

$dns = aws.exe elbv2 describe-load-balancers `
    --names "$ProjectName-external-alb" `
    --query "LoadBalancers[0].DNSName" `
    --output text `
    --profile $Profile `
    --region $Region

if ($LASTEXITCODE -ne 0 -or !$dns -or $dns -eq "None") {
    throw "Could not retrieve the external ALB DNS name."
}

$baseUrl = "http://$($dns.Trim())"

foreach ($path in @("/", "/health", "/api/health")) {
    $url = "$baseUrl$path"

    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest `
            -Uri $url `
            -UseBasicParsing `
            -TimeoutSec 20
        $watch.Stop()

        if ($response.StatusCode -ne 200) {
            throw "HTTP $($response.StatusCode)"
        }

        Write-Host "[PASS] $path - HTTP 200 - $($watch.ElapsedMilliseconds) ms" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] $path - $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "HTTP smoke tests passed." -ForegroundColor Green
