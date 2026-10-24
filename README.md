# AWS Three-Tier Flask Application — Terraform

**A multi-AZ, three-tier AWS deployment provisioned with Terraform, with private application tiers, automated scaling, and operational diagnostics.**

This portfolio project deploys a Flask To-Do application adapted from the [AWS sample](https://github.com/aws-samples/three-tier-web-application-flask). The application is maintained separately in my [modified Flask repository](https://github.com/HamaizKazi/three-tier-web-application-flask), with a versioned deployment and fixes for startup race conditions.

## Architecture

**Request path:** Browser → Internet-facing ALB → private web tier (Nginx + Flask) → internal ALB → private Flask API tier → Amazon RDS MySQL.

The VPC (`10.20.0.0/16`) spans **2 Availability Zones** and **8 subnets**: 2 public, 2 private web, 2 private application, and 2 isolated database subnets. The web and application tiers each run in an Auto Scaling Group with **2 desired / 4 maximum** instances. One NAT Gateway provides outbound access for private instances.

**Architecture diagram:** [Click To View](docs/Architecture.pdf) 

> **Availability scope:** EC2 application tiers span two AZs. The current lab uses a single NAT Gateway and a single RDS instance; the full solution is not fault-tolerant across every component.

## Technology Stack

|           Area              |         Services / Tools                                                    |
|            ---              |               ---                                                           |
| Infrastructure              | Terraform, AWS Provider                                                     |
| Networking                  | VPC, subnets, route tables, Internet Gateway, NAT Gateway, security groups  |
| Traffic management          | External and internal Application Load Balancers                            |
| Compute                     | EC2, Launch Templates, Auto Scaling Groups, rolling instance refresh        |
| Application                 | Nginx, Flask, Gunicorn, Python, SQLAlchemy                                  |
| Database                    | Amazon RDS MySQL (encrypted, not publicly accessible)                       |
| Access and configuration    | IAM, Systems Manager Parameter Store, Session Manager, IMDSv2               |
| Monitoring and operations   | CloudWatch alarm definitions, PowerShell health and smoke-test scripts      |

## Key Engineering Decisions

- **Network isolation:** Only the external ALB is internet-facing; web and API instances run in private subnets, and MySQL is not publicly accessible.

- **Least-privilege access:** EC2 instance roles access the required SSM parameters, including an encrypted `SecureString` database password; Session Manager is used instead of public SSH.

- **Availability and scaling:** Two EC2 instances per application tier across two AZs, CPU target-tracking policies, and rolling instance refreshes.

- **Repeatable app releases:** Both launch templates clone a tagged release of the [application fork](https://github.com/HamaizKazi/three-tier-web-application-flask), rather than the upstream sample's moving default branch.

- **Operational validation:** Custom scripts inspect infrastructure health, Auto Scaling activity, and HTTP endpoints; generated reports are kept locally.

## Repository Layout

```text
aws-three-tier-terraform/
├── scripts/
│   ├── healthcheck.ps1      # Infrastructure health checks
│   └── smoke-test.ps1       # HTTP endpoint tests
├── reports/
│   └── .gitkeep             # Generated reports are ignored
├── alb.tf                  # External/internal ALBs and target groups
├── ami.tf                  # EC2 AMI lookup
├── asg.tf                  # Web and app Auto Scaling Groups
├── iam.tf                  # Instance roles and SSM permissions
├── launch_templates.tf     # EC2 configuration and bootstrap
├── monitoring.tf           # CloudWatch target-health alarms
├── network.tf              # VPC, subnets, NAT and routing
├── outputs.tf              # Deployment outputs
├── parameters.tf           # SSM Parameter Store configuration
├── providers.tf            # AWS provider configuration
├── rds.tf                  # RDS MySQL and DB subnet group
├── scaling.tf              # Auto Scaling policies
├── security.tf             # Security groups
├── variables.tf            # Input variables
├── versions.tf             # Terraform and provider requirements
├── .terraform.lock.hcl     # Provider dependency lock file
├── .gitignore
└── README.md
```


## Deployment

**Prerequisites:** Terraform, AWS CLI, PowerShell, an AWS account with the required provisioning permissions, and the input values expected by the Terraform configuration. This project was tested in **`ap-southeast-2` (Sydney)** using the AWS CLI profile **`aws-learning`**.

**1. Authenticate and configure**

```powershell
aws configure --profile aws-learning
aws sts get-caller-identity --profile aws-learning
$env:AWS_PROFILE = "aws-learning"
```


Review the Terraform input variables before deployment. Supply required values locally or through your environment; **never commit passwords, `.tfvars`, or Terraform state files**.

**2. Initialize, validate, and deploy**

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out=deploy.tfplan
terraform apply deploy.tfplan
```

Review the plan before applying. Provisioning creates billable AWS resources, including ALBs, NAT Gateway, EC2, and RDS.

**3. Verify infrastructure and application**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\healthcheck.ps1 -SaveReport
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1
```

Check that both target groups have **2 healthy targets**, that the Auto Scaling Groups are stable, and that the To-Do application can create, refresh, edit, and delete tasks.

**4. Tear down when finished**

```powershell
terraform plan -destroy
terraform destroy
```

> **Data-loss warning:** Destroying RDS may permanently delete the To-Do database, depending on final snapshot settings. Review the destroy plan before approving it.

## Diagnostics and Reports

| Item | Purpose |
| --- | --- |
| `scripts/healthcheck.ps1` | Read-only checks for ALBs, target health, ASGs and scaling activities, EC2, SSM, RDS, VPC/NAT, Parameter Store metadata, and public `/health` |
| `scripts/smoke-test.ps1` | HTTP probes for `/` (web UI), `/health` (Nginx), and `/api/health` (proxied Flask API path) |
| `reports/` | Timestamped local health snapshots created with `-SaveReport`, useful for comparing deployments and diagnosing failures |

The health dashboard reports **PASS / WARN / FAIL** counts and AWS API errors. HTTP smoke tests do not independently prove database persistence; verify CRUD in the browser as well.

**Reports are intentionally excluded from Git**, because they can contain environment-specific identifiers. Commit only `reports/.gitkeep` using:

gitignore
reports/*
!reports/.gitkeep


## CloudWatch Monitoring

`monitoring.tf` defines two `AWS/ApplicationELB` alarms, one per target group (`app` and `web`), using `UnHealthyHostCount` with **Maximum**, a **60-second period**, a threshold of **≥ 1**, and **2 of 2** evaluation periods. Missing data is treated as not breaching; alarm actions and notifications are disabled.

These are **Terraform definitions**; verify that they have been applied before describing the alarms as active. During learning, equivalent alarms can be configured in the AWS Console, deleted, and then recreated under Terraform management.

## Problems Investigated and Improvements

| Startup problem | Diagnosis | Improvement |
| --- | --- | --- |
| Gunicorn `ParameterNotFound` | App workers requested the RDS endpoint before the SSM parameter was ready | Terraform dependency ordering and bounded SSM-readiness retries before service startup |
| MySQL error `1050: Table 'todotable' already exists` | Gunicorn workers could initialize the same schema concurrently | Coordinated schema initialization in the application fork |

The modified application release **`v0.1.0`** (`4068d45`) was deployed through a rolling instance refresh. Inspection of one new app instance found no matching startup errors.

## Verified Results — October 23, 2026

| Validation | Result |
| --- | --- |
| Infrastructure dashboard | **33 passed, 0 warnings, 0 failures, 0 API errors** |
| Web / app target groups | **2/2 healthy** each |
| Web / app Auto Scaling refresh | **Successful, 100%** each |
| EC2 / Session Manager | All 4 instances healthy and online |
| RDS MySQL | Available, encrypted, not publicly accessible |
| Public `/health` | HTTP 200 |
| Flask To-Do website | Confirmed accessible in browser |

These are **point-in-time results**, not an uptime guarantee or a claim that every CRUD operation was automated and tested. Python 3.11 migration and the final Terraform-managed CloudWatch alarm rollout should be recorded as verified only after their own checks pass.

## Limitations and Next Steps

The current project is an educational deployment, **not a production-ready architecture**. Priorities include HTTPS with ACM, a validated newer Python runtime, centralized application logs, CI/CD, dedicated database migrations, stronger API tests, a redundant NAT design, and an appropriate RDS high-availability configuration.

## Attribution

The Flask application is adapted from [AWS Samples — Three-Tier Web Application Flask](https://github.com/aws-samples/three-tier-web-application-flask) under the **MIT-0** license. The original license is retained in the [application fork](https://github.com/HamaizKazi/three-tier-web-application-flask).
