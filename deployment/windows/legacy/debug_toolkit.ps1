# AWS App Runner Custom Domain Debugging Toolkit
# Collection of all debugging and diagnostic commands used during setup

param(
    [string]$Domain = "rickarko.com",
    [string]$ServiceArn = "arn:aws:apprunner:us-east-1:122610507380:service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7",
    [string]$Region = "us-east-1",
    [string]$HostedZoneId = "Z08302203OZOEJNRETXLE",
    [switch]$DetailedOutput,
    [switch]$ContinuousMonitor
)

Write-Host "=== AWS App Runner Domain Debugging Toolkit ===" -ForegroundColor Cyan
Write-Host "Domain: $Domain" -ForegroundColor Yellow
Write-Host "Service ARN: $ServiceArn" -ForegroundColor Yellow  
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Hosted Zone: $HostedZoneId" -ForegroundColor Yellow
Write-Host ""

# Function: Check nameserver propagation
function Test-Nameservers {
    param([string]$Domain)
    
    Write-Host "=== Nameserver Status ===" -ForegroundColor Green
    try {
        $nsLookup = nslookup -type=NS $Domain 2>$null
        $nameservers = $nsLookup | Where-Object { $_ -match "nameserver" }
        
        $hasAWSNS = $false
        foreach ($line in $nameservers) {
            $ns = ($line -split "=")[1].Trim()
            if ($ns -like "*awsdns*") {
                Write-Host "✓ AWS: $ns" -ForegroundColor Green
                $hasAWSNS = $true
            } elseif ($ns -like "*domaincontrol*") {
                Write-Host "❌ GoDaddy: $ns (needs change)" -ForegroundColor Red
            } else {
                Write-Host "⚠️ Other: $ns" -ForegroundColor Yellow
            }
        }
        
        if ($hasAWSNS) {
            Write-Host "✓ Nameservers pointing to AWS" -ForegroundColor Green
        } else {
            Write-Host "❌ Nameservers NOT pointing to AWS - update at domain registrar!" -ForegroundColor Red
        }
        
        return $hasAWSNS
    } catch {
        Write-Host "❌ Failed to check nameservers: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function: Check App Runner domain status
function Test-AppRunnerStatus {
    param([string]$ServiceArn, [string]$Region)
    
    Write-Host "`n=== App Runner Domain Status ===" -ForegroundColor Green
    try {
        # Get basic status
        $status = aws apprunner describe-custom-domains --service-arn $ServiceArn --region $Region --query 'CustomDomains[0].Status' --output text
        
        switch ($status) {
            "active" { 
                Write-Host "✅ Status: $status - Domain is ready!" -ForegroundColor Green 
                return $true
            }
            "pending_certificate_dns_validation" { 
                Write-Host "⏳ Status: $status - Waiting for DNS validation" -ForegroundColor Yellow 
                return $false
            }
            "pending_domain_dns_validation" { 
                Write-Host "⏳ Status: $status - Validating domain ownership" -ForegroundColor Yellow 
                return $false
            }
            default { 
                Write-Host "❓ Status: $status - Unknown status" -ForegroundColor Red 
                return $false
            }
        }
    } catch {
        Write-Host "❌ Failed to check App Runner status: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function: Check DNS records in Route 53
function Test-Route53Records {
    param([string]$HostedZoneId, [string]$Domain)
    
    Write-Host "`n=== Route 53 DNS Records ===" -ForegroundColor Green
    try {
        $records = aws route53 list-resource-record-sets --hosted-zone-id $HostedZoneId --output json | ConvertFrom-Json
        
        $hasCNAME = $false
        foreach ($record in $records.ResourceRecordSets) {
            if ($record.Name -eq "$Domain." -or $record.Name -eq $Domain) {
                Write-Host "Record: $($record.Name) ($($record.Type))" -ForegroundColor Cyan
                if ($record.Type -eq "CNAME") {
                    $target = $record.ResourceRecords[0].Value
                    Write-Host "  → Points to: $target" -ForegroundColor Green
                    if ($target -like "*awsapprunner.com") {
                        Write-Host "  ✓ Correctly points to App Runner" -ForegroundColor Green
                        $hasCNAME = $true
                    } else {
                        Write-Host "  ⚠️ Does not point to App Runner service" -ForegroundColor Yellow
                    }
                }
            }
        }
        
        if (-not $hasCNAME) {
            Write-Host "❌ Missing CNAME record for $Domain" -ForegroundColor Red
            Write-Host "💡 Need to create: $Domain → your-service.awsapprunner.com" -ForegroundColor Yellow
        }
        
        return $hasCNAME
    } catch {
        Write-Host "❌ Failed to check Route 53 records: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function: Test domain connectivity
function Test-DomainConnectivity {
    param([string]$Domain)
    
    Write-Host "`n=== Domain Connectivity Test ===" -ForegroundColor Green
    
    # Test HTTP
    try {
        $httpResponse = Invoke-WebRequest -Uri "http://$Domain" -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✓ HTTP accessible (Status: $($httpResponse.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "❌ HTTP not accessible: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test HTTPS
    try {
        $httpsResponse = Invoke-WebRequest -Uri "https://$Domain" -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ HTTPS accessible (Status: $($httpsResponse.StatusCode))" -ForegroundColor Green
        Write-Host "🎉 SUCCESS: Domain is fully working!" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ HTTPS not accessible: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function: Get expected AWS nameservers
function Get-ExpectedNameservers {
    param([string]$HostedZoneId)
    
    Write-Host "`n=== Expected AWS Nameservers ===" -ForegroundColor Green
    try {
        Write-Host "Update these at your domain registrar:" -ForegroundColor Yellow
        aws route53 get-hosted-zone --id $HostedZoneId --query 'DelegationSet.NameServers[]' --output table
    } catch {
        Write-Host "❌ Failed to get nameservers: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function: Comprehensive status report
function Get-StatusReport {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "COMPREHENSIVE STATUS REPORT" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    $nsOK = Test-Nameservers -Domain $Domain
    $arOK = Test-AppRunnerStatus -ServiceArn $ServiceArn -Region $Region  
    $dnsOK = Test-Route53Records -HostedZoneId $HostedZoneId -Domain $Domain
    $domainOK = Test-DomainConnectivity -Domain $Domain
    
    Write-Host "`n" + "-"*60 -ForegroundColor Gray
    Write-Host "SUMMARY:" -ForegroundColor Cyan
    Write-Host "Nameservers: $(if ($nsOK) {"✅ OK"} else {"❌ NEEDS FIX"})" -ForegroundColor $(if ($nsOK) {"Green"} else {"Red"})
    Write-Host "App Runner: $(if ($arOK) {"✅ OK"} else {"⏳ PENDING"})" -ForegroundColor $(if ($arOK) {"Green"} else {"Yellow"})  
    Write-Host "DNS Records: $(if ($dnsOK) {"✅ OK"} else {"❌ NEEDS FIX"})" -ForegroundColor $(if ($dnsOK) {"Green"} else {"Red"})
    Write-Host "Domain Live: $(if ($domainOK) {"✅ OK"} else {"❌ NOT READY"})" -ForegroundColor $(if ($domainOK) {"Green"} else {"Red"})
    
    if ($domainOK) {
        Write-Host "`n🎉 DOMAIN IS FULLY WORKING!" -ForegroundColor Green
        Write-Host "Visit: https://$Domain" -ForegroundColor Green
    } elseif (-not $nsOK) {
        Write-Host "`n🔧 NEXT ACTION: Update nameservers at domain registrar" -ForegroundColor Yellow
        Get-ExpectedNameservers -HostedZoneId $HostedZoneId
    } elseif (-not $dnsOK) {
        Write-Host "`n🔧 NEXT ACTION: Create missing DNS records in Route 53" -ForegroundColor Yellow
    } else {
        Write-Host "`n⏳ NEXT ACTION: Wait for DNS propagation and validation (5-30 minutes)" -ForegroundColor Yellow
    }
}

# Main execution based on parameters
if ($ContinuousMonitor) {
    Write-Host "Starting continuous monitoring (Ctrl+C to stop)..." -ForegroundColor Cyan
    while ($true) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "`n[$timestamp] Checking status..." -ForegroundColor Gray
        
        $arStatus = Test-AppRunnerStatus -ServiceArn $ServiceArn -Region $Region
        $domainStatus = Test-DomainConnectivity -Domain $Domain
        
        if ($domainStatus) {
            Write-Host "`n🎉 SUCCESS! Domain is working at $timestamp" -ForegroundColor Green
            break
        }
        
        Write-Host "Waiting 30 seconds..." -ForegroundColor Gray
        Start-Sleep 30
    }
} else {
    # Run full status report
    Get-StatusReport
    
    if ($DetailedOutput) {
        Write-Host "`n=== DETAILED DEBUGGING COMMANDS ===" -ForegroundColor Cyan
        
        Write-Host "`nApp Runner Service Details:" -ForegroundColor Green
        aws apprunner describe-service --service-arn $ServiceArn --region $Region --query 'Service.{Name:ServiceName,Status:Status,ServiceUrl:ServiceUrl}' --output table
        
        Write-Host "`nRoute 53 All Records:" -ForegroundColor Green  
        aws route53 list-resource-record-sets --hosted-zone-id $HostedZoneId --output table
        
        Write-Host "`nApp Runner Custom Domains (Full):" -ForegroundColor Green
        aws apprunner describe-custom-domains --service-arn $ServiceArn --region $Region --output json
    }
}

# Provide quick commands for manual testing
Write-Host "`n" + "="*60 -ForegroundColor Gray
Write-Host "QUICK MANUAL COMMANDS:" -ForegroundColor Gray
Write-Host "="*60 -ForegroundColor Gray
Write-Host "# Check nameservers:"
Write-Host "nslookup -type=NS $Domain" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Check App Runner status:"  
Write-Host "aws apprunner describe-custom-domains --service-arn $ServiceArn --region $Region --query 'CustomDomains[0].Status'" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Test domain:"
Write-Host "Test-NetConnection $Domain -Port 443" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Continuous monitoring:"
Write-Host ".\debug_toolkit.ps1 -ContinuousMonitor" -ForegroundColor Cyan
