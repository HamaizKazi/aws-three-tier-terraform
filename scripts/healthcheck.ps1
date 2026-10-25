
param(
    [string]$ProjectName = "aws-terraform",
    [string]$AwsProfile = "aws-learning",
    [string]$Region = "ap-southeast-2",
    [switch]$SaveReport
)

$env:AWS_PAGER = ""
$script:Pass = 0
$script:Warn = 0
$script:Fail = 0
$script:ApiErrors = 0

function Section($Name) {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host " $Name" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Check($Level, $Message) {
    $color = switch ($Level) {
        "PASS" { $script:Pass++; "Green" }
        "WARN" { $script:Warn++; "Yellow" }
        "FAIL" { $script:Fail++; "Red" }
        default { "Gray" }
    }
    Write-Host ("[{0,-4}] {1}" -f $Level, $Message) -ForegroundColor $color
}

function AWS([string[]]$Parts) {
    $raw = & aws.exe @Parts --profile $AwsProfile --region $Region --output json --no-cli-pager 2>&1

    if ($LASTEXITCODE -ne 0) {
        $script:ApiErrors++
        Check "WARN" ("AWS request failed: " + ($Parts -join " "))
        Write-Host ($raw | Out-String) -ForegroundColor DarkYellow
        return $null
    }

    try {
        return (($raw | Out-String) | ConvertFrom-Json)
    }
    catch {
        $script:ApiErrors++
        Check "WARN" "Could not parse AWS response."
        return $null
    }
}

if (-not (Get-Command aws.exe -ErrorAction SilentlyContinue)) {
    throw "AWS CLI is not installed or not available in PATH."
}

if ($SaveReport) {
    New-Item -ItemType Directory -Path ".\reports" -Force | Out-Null
    $file = ".\reports\health-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    Start-Transcript -Path $file | Out-Null
}

Section "AWS PROJECT HEALTH DASHBOARD"
Write-Host "Project : $ProjectName"
Write-Host "Region  : $Region"
Write-Host "Profile : $AwsProfile"
Write-Host "Checked : $(Get-Date)"

$identity = AWS -Parts @("sts", "get-caller-identity")
if (-not $identity) {
    throw "AWS authentication failed. Check profile and credentials."
}
Check "PASS" "AWS authentication successful"

# --------------------------------------------
# 1. LOAD BALANCERS
# --------------------------------------------

Section "1. APPLICATION LOAD BALANCERS"

$lbs = AWS -Parts @("elbv2", "describe-load-balancers")
$projectLbs = @($lbs.LoadBalancers | Where-Object {
    $_.LoadBalancerName -like "$ProjectName-*"
})

if ($projectLbs.Count -eq 0) {
    Check "FAIL" "No project load balancers found."
}

foreach ($lb in $projectLbs) {
    $level = if ($lb.State.Code -eq "active") { "PASS" } else { "WARN" }
    Check $level "$($lb.LoadBalancerName): $($lb.State.Code)"
    Write-Host "  Scheme : $($lb.Scheme)"
    Write-Host "  DNS    : $($lb.DNSName)"

    $listeners = AWS -Parts @(
        "elbv2", "describe-listeners",
        "--load-balancer-arn", $lb.LoadBalancerArn
    )

    foreach ($listener in $listeners.Listeners) {
        Write-Host "  Listener: $($listener.Protocol):$($listener.Port)"
    }
}

# --------------------------------------------
# 2. TARGET GROUP HEALTH
# --------------------------------------------

Section "2. TARGET GROUP HEALTH CHECKS"

$tgs = AWS -Parts @("elbv2", "describe-target-groups")
$projectTgs = @($tgs.TargetGroups | Where-Object {
    $_.TargetGroupName -like "$ProjectName-*"
})

if ($projectTgs.Count -eq 0) {
    Check "FAIL" "No project target groups found."
}

foreach ($tg in $projectTgs) {
    Write-Host "`nTarget group: $($tg.TargetGroupName)" -ForegroundColor White
    Write-Host "  Health path : $($tg.HealthCheckPath)"
    Write-Host "  Health port : $($tg.HealthCheckPort)"
    Write-Host "  Expected HTTP: $($tg.Matcher.HttpCode)"

    $health = AWS -Parts @(
        "elbv2", "describe-target-health",
        "--target-group-arn", $tg.TargetGroupArn
    )

    $targets = @($health.TargetHealthDescriptions | Where-Object { $_ })

    if ($targets.Count -eq 0) {
        Check "FAIL" "No registered targets."
    }

    foreach ($target in $targets) {
        $state = $target.TargetHealth.State
        $id = $target.Target.Id
        $reason = $target.TargetHealth.Reason
        $description = $target.TargetHealth.Description

        $level = if ($state -eq "healthy") {
            "PASS"
        }
        elseif ($state -eq "initial" -or $state -eq "draining") {
            "WARN"
        }
        else {
            "FAIL"
        }

        Check $level "$id : $state"

        if ($reason) {
            Write-Host "    Reason: $reason" -ForegroundColor Yellow
        }

        if ($description) {
            Write-Host "    Detail: $description"
        }
    }
}

# --------------------------------------------
# 3. AUTO SCALING GROUPS
# --------------------------------------------

Section "3. AUTO SCALING GROUPS"

$asgs = AWS -Parts @("autoscaling", "describe-auto-scaling-groups")
$projectAsgs = @($asgs.AutoScalingGroups | Where-Object {
    $_.AutoScalingGroupName -like "$ProjectName-*"
})

if ($projectAsgs.Count -eq 0) {
    Check "FAIL" "No project Auto Scaling Groups found."
}

foreach ($group in $projectAsgs) {
    Write-Host "`nASG: $($group.AutoScalingGroupName)" -ForegroundColor White
    Write-Host "  Minimum : $($group.MinSize)"
    Write-Host "  Desired : $($group.DesiredCapacity)"
    Write-Host "  Maximum : $($group.MaxSize)"

    $members = @($group.Instances | Where-Object { $_ })

    if ($members.Count -lt $group.DesiredCapacity) {
        Check "WARN" "ASG is below desired instance capacity."
    }
    else {
        Check "PASS" "ASG has at least desired capacity."
    }

    foreach ($member in $members) {
        $level = if ($member.HealthStatus -eq "Healthy") {
            "PASS"
        }
        else {
            "FAIL"
        }

        Check $level "$($member.InstanceId) : $($member.HealthStatus)"
        Write-Host "    Lifecycle: $($member.LifecycleState)"
    }

    Write-Host "`n  Scaling policies:"
    $policies = AWS -Parts @(
        "autoscaling", "describe-policies",
        "--auto-scaling-group-name", $group.AutoScalingGroupName
    )

    foreach ($policy in $policies.ScalingPolicies) {
        Write-Host "    $($policy.PolicyName) ($($policy.PolicyType))"
        if ($policy.TargetTrackingConfiguration) {
            Write-Host "    Target: $($policy.TargetTrackingConfiguration.TargetValue)"
        }
    }

    if ($policies -and -not $policies.ScalingPolicies) {
        Check "WARN" "No scaling policies configured."
    }

    Write-Host "`n  Recent scaling activity:"
    $activities = AWS -Parts @(
        "autoscaling", "describe-scaling-activities",
        "--auto-scaling-group-name", $group.AutoScalingGroupName,
        "--max-items", "5"
    )

    foreach ($activity in $activities.Activities) {
        Write-Host "    $($activity.StatusCode): $($activity.Description)"

        if ($activity.StatusCode -eq "Failed") {
            Check "FAIL" "Scaling activity failed."
            Write-Host "    $($activity.StatusMessage)" -ForegroundColor Red
        }
    }
}

# --------------------------------------------
# 4. EC2 INSTANCES + AWS STATUS CHECKS
# --------------------------------------------

Section "4. EC2 INSTANCE HEALTH"

$ec2 = AWS -Parts @(
    "ec2", "describe-instances",
    "--filters",
    "Name=tag:Project,Values=$ProjectName",
    "Name=instance-state-name,Values=pending,running,stopping,stopped"
)

$instances = @(
    foreach ($reservation in $ec2.Reservations) {
        foreach ($instance in $reservation.Instances) {
            $instance
        }
    }
)

$ids = @($instances | ForEach-Object { $_.InstanceId })

$statusData = $null

if ($ids.Count -gt 0) {
    $statusData = AWS -Parts (
        @("ec2", "describe-instance-status", "--include-all-instances", "--instance-ids") + $ids
    )
}

if ($instances.Count -eq 0) {
    Check "FAIL" "No project EC2 instances found."
}

foreach ($instance in $instances) {
    $state = $instance.State.Name
    $level = if ($state -eq "running") { "PASS" } else { "WARN" }

    Check $level "$($instance.InstanceId) : $state"
    Write-Host "  Type       : $($instance.InstanceType)"
    Write-Host "  Private IP : $($instance.PrivateIpAddress)"
    Write-Host "  Subnet     : $($instance.SubnetId)"

    $status = $statusData.InstanceStatuses | Where-Object {
        $_.InstanceId -eq $instance.InstanceId
    } | Select-Object -First 1

    if ($status) {
        $system = $status.SystemStatus.Status
        $instanceCheck = $status.InstanceStatus.Status

        $level = if ($system -eq "ok" -and $instanceCheck -eq "ok") {
            "PASS"
        }
        elseif ($system -eq "impaired" -or $instanceCheck -eq "impaired") {
            "FAIL"
        }
        else {
            "WARN"
        }

        Check $level "AWS status checks: System=$system Instance=$instanceCheck"
    }
}

# --------------------------------------------
# 5. SYSTEMS MANAGER
# --------------------------------------------

Section "5. SESSION MANAGER CONNECTIVITY"

$ssm = AWS -Parts @("ssm", "describe-instance-information")

foreach ($instance in $instances) {
    $managed = $ssm.InstanceInformationList | Where-Object {
        $_.InstanceId -eq $instance.InstanceId
    } | Select-Object -First 1

    if (-not $ssm) {
        Check "WARN" "SSM connectivity could not be checked."
        break
    }

    if ($managed -and $managed.PingStatus -eq "Online") {
        Check "PASS" "$($instance.InstanceId): SSM Online"
    }
    else {
        Check "WARN" "$($instance.InstanceId): SSM Offline or not registered"
    }
}

# --------------------------------------------
# 6. RDS DATABASE
# --------------------------------------------

Section "6. RDS MYSQL DATABASE"

$rds = AWS -Parts @("rds", "describe-db-instances")
$databases = @($rds.DBInstances | Where-Object {
    $_.DBInstanceIdentifier -like "$ProjectName-*"
})

if ($databases.Count -eq 0) {
    Check "FAIL" "No project RDS database found."
}

foreach ($db in $databases) {
    $level = if ($db.DBInstanceStatus -eq "available") {
        "PASS"
    }
    else {
        "WARN"
    }

    Check $level "$($db.DBInstanceIdentifier): $($db.DBInstanceStatus)"
    Write-Host "  Engine    : $($db.Engine)"
    Write-Host "  Class     : $($db.DBInstanceClass)"
    Write-Host "  Endpoint  : $($db.Endpoint.Address)"
    Write-Host "  Encrypted : $($db.StorageEncrypted)"
    Write-Host "  Public    : $($db.PubliclyAccessible)"

    if ($db.PubliclyAccessible) {
        Check "FAIL" "Database is publicly accessible."
    }
}

# --------------------------------------------
# 7. VPC AND NAT NETWORKING
# --------------------------------------------

Section "7. NETWORKING"

$vpcs = AWS -Parts @(
    "ec2", "describe-vpcs",
    "--filters", "Name=tag:Project,Values=$ProjectName"
)

foreach ($vpc in $vpcs.Vpcs) {
    Check "PASS" "VPC: $($vpc.VpcId) ($($vpc.CidrBlock))"
}

if ($vpcs -and -not $vpcs.Vpcs) {
    Check "FAIL" "Project VPC not found."
}

$subnets = AWS -Parts @(
    "ec2", "describe-subnets",
    "--filters", "Name=tag:Project,Values=$ProjectName"
)

foreach ($subnet in $subnets.Subnets) {
    Write-Host "Subnet: $($subnet.SubnetId) | $($subnet.AvailabilityZone) | $($subnet.CidrBlock)"
}

$nat = AWS -Parts @(
    "ec2", "describe-nat-gateways",
    "--filter", "Name=tag:Project,Values=$ProjectName"
)

$activeNat = @($nat.NatGateways | Where-Object {
    $_.State -eq "available"
})

if ($nat -and $activeNat.Count -eq 0) {
    Check "FAIL" "No available NAT Gateway."
}

foreach ($gateway in $nat.NatGateways) {
    $level = if ($gateway.State -eq "available") { "PASS" } else { "WARN" }
    Check $level "NAT $($gateway.NatGatewayId): $($gateway.State)"
}

# --------------------------------------------
# 8. PARAMETER STORE (METADATA ONLY)
# --------------------------------------------

Section "8. SSM PARAMETER STORE"

$parameters = AWS -Parts @("ssm", "describe-parameters")
$expected = @(
    "master_username",
    "db_password",
    "endpoint",
    "db_instance_name"
)

if ($parameters) {
    foreach ($name in $expected) {
        $item = $parameters.Parameters | Where-Object {
            $_.Name -eq $name -or $_.Name -eq "/$name"
        } | Select-Object -First 1

        if ($item) {
            Check "PASS" "$name exists ($($item.Type))"
        }
        else {
            Check "FAIL" "$name missing"
        }
    }
}


Section "DEPLOYMENT READINESS"

foreach ($tier in @("web", "app")) {
    $asgName = "$ProjectName-$tier-asg"
    $tgName = "$ProjectName-$tier-tg"

    $group = $projectAsgs | Where-Object {
        $_.AutoScalingGroupName -eq $asgName
    } | Select-Object -First 1

    $targetGroup = $projectTgs | Where-Object {
        $_.TargetGroupName -eq $tgName
    } | Select-Object -First 1

    if (-not $group -or -not $targetGroup) {
        Check "FAIL" "$tier tier: expected ASG or target group missing."
        continue
    }

    $desired = [int]$group.DesiredCapacity

    if ($desired -lt 1) {
        Check "FAIL" "$tier tier: desired capacity is zero."
        continue
    }

    $readyMembers = @($group.Instances | Where-Object {
        $_.LifecycleState -eq "InService" -and
        $_.HealthStatus -eq "Healthy"
    })

    $health = AWS -Parts @(
        "elbv2", "describe-target-health",
        "--target-group-arn", $targetGroup.TargetGroupArn
    )

    if (-not $health) {
        Check "FAIL" "$tier tier: target readiness could not be verified."
        continue
    }

    $healthyIds = @(
        $health.TargetHealthDescriptions |
        Where-Object { $_.TargetHealth.State -eq "healthy" } |
        ForEach-Object { $_.Target.Id }
    )

    $readyIds = @(
        $readyMembers |
        Where-Object { $healthyIds -contains $_.InstanceId } |
        ForEach-Object { $_.InstanceId }
    )

    if ($readyIds.Count -ge $desired) {
        Check "PASS" "$tier tier: $($readyIds.Count)/$desired desired instances are InService and ALB-healthy."
    }
    else {
        Check "FAIL" "$tier tier not ready: $($readyIds.Count)/$desired desired instances are InService and ALB-healthy."
    }
}


# --------------------------------------------
# 9. PUBLIC HTTP HEALTH
# --------------------------------------------

Section "9. APPLICATION HTTP CHECKS"

$publicLb = $projectLbs | Where-Object {
    $_.LoadBalancerName -eq "$ProjectName-external-alb"
} | Select-Object -First 1

if (-not $publicLb) {
    Check "FAIL" "External ALB missing; application checks cannot run."
}
else {
    $checks = @(
        @{ Path = "/"; Label = "Web homepage" },
        @{ Path = "/health"; Label = "Nginx health only" },
        @{ Path = "/api/health"; Label = "Proxied application health" }
    )

    foreach ($test in $checks) {
        $url = "http://$($publicLb.DNSName)$($test.Path)"

        try {
            $watch = [Diagnostics.Stopwatch]::StartNew()

            $response = Invoke-WebRequest `
                -Uri $url `
                -UseBasicParsing `
                -TimeoutSec 20 `
                -MaximumRedirection 0 `
                -ErrorAction Stop

            $watch.Stop()

            if ($response.StatusCode -eq 200) {
                Check "PASS" "$($test.Label): HTTP 200 in $($watch.ElapsedMilliseconds) ms."
            }
            else {
                Check "FAIL" "$($test.Label): HTTP $($response.StatusCode)."
            }
        }
        catch {
            Check "FAIL" "$($test.Label): $($_.Exception.Message)"
        }
    }
}


Section "10. HARDENING CONFIGURATION"

# ALB attributes
foreach ($name in @(
    "$ProjectName-external-alb",
    "$ProjectName-internal-alb"
)) {
    $lb = $projectLbs | Where-Object {
        $_.LoadBalancerName -eq $name
    } | Select-Object -First 1

    if (-not $lb) {
        Check "FAIL" "Expected ALB missing: $name"
        continue
    }

    $result = AWS -Parts @(
        "elbv2", "describe-load-balancer-attributes",
        "--load-balancer-arn", $lb.LoadBalancerArn
    )

    if (-not $result) {
        Check "FAIL" "$name attributes could not be verified."
        continue
    }

    $attributes = @{}
    foreach ($attribute in $result.Attributes) {
        $attributes[$attribute.Key] = $attribute.Value
    }

    foreach ($key in @(
        "routing.http.drop_invalid_header_fields.enabled",
        "deletion_protection.enabled",
        "access_logs.s3.enabled"
    )) {
        $level = if ($attributes[$key] -eq "true") {
            "PASS"
        } else {
            "FAIL"
        }

        Check $level "$name : $key = $($attributes[$key])"
    }

    if ($attributes["access_logs.s3.enabled"] -eq "true") {
        Write-Host "  Log bucket: $($attributes['access_logs.s3.bucket'])"
        Write-Host "  Log prefix: $($attributes['access_logs.s3.prefix'])"
        Write-Host "  Configuration verified; actual log delivery needs separate evidence."
    }
}

# RDS hardening
foreach ($db in $databases) {
    foreach ($setting in @(
        @{ Name = "Storage encryption"; Good = $db.StorageEncrypted },
        @{ Name = "Private access"; Good = -not $db.PubliclyAccessible },
        @{ Name = "Deletion protection"; Good = $db.DeletionProtection },
        @{ Name = "Snapshot tag copying"; Good = $db.CopyTagsToSnapshot }
    )) {
        $level = if ($setting.Good) { "PASS" } else { "FAIL" }
        Check $level "$($db.DBInstanceIdentifier): $($setting.Name)"
    }

    if ($db.MonitoringInterval -eq 60 -and $db.MonitoringRoleArn) {
        Check "PASS" "RDS Enhanced Monitoring configured at 60 seconds."
    }
    else {
        Check "FAIL" "RDS Enhanced Monitoring differs from the expected 60-second configuration."
    }

    foreach ($logType in @("error", "general", "slowquery")) {
        $level = if ($db.EnabledCloudwatchLogsExports -contains $logType) {
            "PASS"
        } else {
            "FAIL"
        }

        Check $level "RDS $logType log export configured."
    }

    foreach ($parameterGroup in $db.DBParameterGroups) {
        $level = if ($parameterGroup.ParameterApplyStatus -eq "in-sync") {
            "PASS"
        } else {
            "WARN"
        }

        Check $level "RDS parameter group $($parameterGroup.DBParameterGroupName): $($parameterGroup.ParameterApplyStatus)"
    }

    Write-Host "  Lab context: Single-AZ and password authentication are documented trade-offs."
}

# Password metadata and KMS key; never retrieve parameter values
$passwordParameter = $parameters.Parameters | Where-Object {
    $_.Name -eq "db_password"
} | Select-Object -First 1

if (-not $passwordParameter -or $passwordParameter.Type -ne "SecureString") {
    Check "FAIL" "Database password parameter missing or not SecureString."
}
elseif (-not $passwordParameter.KeyId) {
    Check "FAIL" "Password parameter KMS key could not be identified."
}
else {
    $key = AWS -Parts @(
        "kms", "describe-key",
        "--key-id", $passwordParameter.KeyId
    )

    if ($key -and
        $key.KeyMetadata.KeyManager -eq "CUSTOMER" -and
        $key.KeyMetadata.KeyState -eq "Enabled") {
        Check "PASS" "Password parameter uses an enabled customer-managed KMS key."
    }
    else {
        Check "FAIL" "Password parameter customer-managed key could not be verified as enabled."
    }
}

# Subnet public-IP defaults
foreach ($subnet in $subnets.Subnets) {
    $level = if ($subnet.MapPublicIpOnLaunch) { "FAIL" } else { "PASS" }
    Check $level "$($subnet.SubnetId): automatic public IPv4 assignment disabled."
}

# CloudWatch alarms
foreach ($tier in @("web", "app")) {
    $alarmName = "$ProjectName-$tier-unhealthy-targets"

    $result = AWS -Parts @(
        "cloudwatch", "describe-alarms",
        "--alarm-names", $alarmName
    )

    $alarm = $result.MetricAlarms | Select-Object -First 1

    if (-not $alarm) {
        Check "FAIL" "Alarm missing or could not be checked: $alarmName"
        continue
    }

    $level = switch ($alarm.StateValue) {
        "OK" { "PASS" }
        "ALARM" { "FAIL" }
        default { "WARN" }
    }

    Check $level "$alarmName state: $($alarm.StateValue)"

    if ($alarm.ActionsEnabled) {
        Check "PASS" "$alarmName actions enabled."
    }
    else {
        Check "FAIL" "$alarmName actions disabled."
    }

    if (@($alarm.AlarmActions | Where-Object { $_ }).Count -eq 0) {
        Check "WARN" "$alarmName has no ALARM action destination; no configured action will run when it enters ALARM."
    }

    Write-Host "  Alarm OK alone does not prove readiness; missing data may be treated as not breaching."
}


# --------------------------------------------
# FINAL SUMMARY
# --------------------------------------------

Section "FINAL DIAGNOSTIC SUMMARY"

Write-Host "Passed   : $script:Pass" -ForegroundColor Green
Write-Host "Warnings : $script:Warn" -ForegroundColor Yellow
Write-Host "Failures : $script:Fail" -ForegroundColor Red
Write-Host "API errors: $script:ApiErrors"

if ($script:Fail -eq 0 -and $script:Warn -eq 0 -and $script:ApiErrors -eq 0) {
    Write-Host "`nALL CHECKED COMPONENTS PASSED" -ForegroundColor Green
}
else {
    Write-Host "`nATTENTION REQUIRED - REVIEW ITEMS ABOVE" -ForegroundColor Yellow
}

Write-Host "`nNote: These checks do not prove database connectivity or full CRUD functionality."

if ($SaveReport) {
    Stop-Transcript | Out-Null
    Write-Host "`nNote: This is a point-in-time check. It does not prove CRUD persistence, instance bootstrap completion, or actual log delivery."
}

if ($script:Fail -gt 0 -or $script:ApiErrors -gt 0) {
    exit 1
}

exit 0
