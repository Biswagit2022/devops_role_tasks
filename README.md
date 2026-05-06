# AWS Application Infrastructure

Production-grade AWS infrastructure for hosting a containerized web application, provisioned with Terraform and deployed via GitHub Actions CI/CD.

## What This Builds

A multi-AZ AWS environment in `ap-south-1` (Mumbai):

- **VPC** with public + private subnets across 2 availability zones
- **Application Load Balancer** (public) → **ECS Fargate** (private) for app hosting
- **RDS PostgreSQL** (private) for database
- **NAT Gateways** for private subnet outbound traffic
- **Security Groups** with least-privilege chained access (Internet → ALB → ECS → RDS)
- **AWS Secrets Manager** for database credentials
- **Automated daily backups** via RDS snapshots (7-day retention)
- **CI/CD pipelines** via GitHub Actions with manual production approval gate

## Architecture

```
Internet
   │
   ▼
┌──────────────────────────────────────────────┐
│  Public Subnets (2 AZs)                      │
│  ┌──────────────────┐                        │
│  │ Application LB   │                        │
│  └────────┬─────────┘                        │
│           │                                  │
│  ┌────────▼─────────┐  ┌──────────────────┐  │
│  │  NAT Gateway AZ1 │  │ NAT Gateway AZ2  │  │
│  └────────┬─────────┘  └────────┬─────────┘  │
└───────────┼─────────────────────┼────────────┘
            │                     │
┌───────────┼─────────────────────┼────────────┐
│  Private Subnets (2 AZs)        │            │
│  ┌────────▼─────────────────────▼─────────┐  │
│  │  ECS Fargate Tasks (auto-scaled)       │  │
│  └────────────────┬───────────────────────┘  │
│                   │                          │
│  ┌────────────────▼───────────────────────┐  │
│  │  RDS PostgreSQL (encrypted)            │  │
│  │  + Daily automated backups             │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

## Folder Structure

```
devops_role_tasks/
├── .github/
│   └── workflows/
│       ├── 1-pr-checks.yml          # Tests + security scans on PR
│       ├── 2-deploy-staging.yml     # Auto-deploy on merge to main
│       └── 3-deploy-production.yml  # Manual approval gate
├── modules/
│   ├── vpc/                         # Networking
│   ├── security/                    # Security groups
│   ├── rds/                         # PostgreSQL database
│   ├── alb/                         # Load balancer
│   ├── ecs/                         # Container orchestration
│   └── secrets/                     # Secrets Manager
├── backend.tf                       # Remote state (S3 + DynamoDB)
├── providers.tf                     # AWS provider configuration
├── variables.tf                     # Input variables
├── terraform.tfvars                 # Your values (gitignored)
├── terraform.tfvars.example         # Template
├── outputs.tf                       # Exported resource info
├── main.tf                          # Module wiring
├── Dockerfile                       # Application container
└── README.md
```

## Setup Instructions

### Prerequisites

- AWS account with admin or equivalent permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.6.0
- A GitHub repository for the CI/CD pipelines
- Docker (for local image testing)

### Step 1: Bootstrap Remote State Backend

The S3 bucket and DynamoDB table must exist before Terraform's backend can use them.

```bash
# Create state bucket (name must be globally unique)
aws s3api create-bucket \
  --bucket your-tfstate-ap-south-1 \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable versioning (recovery from bad state writes)
aws s3api put-bucket-versioning \
  --bucket your-tfstate-ap-south-1 \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-tfstate-ap-south-1 \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket your-tfstate-ap-south-1 \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicAccess=true"

# Lock table (prevents concurrent state modification)
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

Then uncomment the `backend "s3"` block in `backend.tf` with your bucket name.

### Step 2: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set project_name, environment, db_password
```

### Step 3: Deploy

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Expected duration: ~12 minutes (RDS is the slow part).

### Step 4: Verify

```bash
# Get the load balancer URL
terraform output alb_dns_name

# Test it
curl http://$(terraform output -raw alb_dns_name)
```

### Step 5: Set Up CI/CD

See `.github/workflows/` for pipeline definitions. Required GitHub configuration:

**Secrets** (Repo → Settings → Secrets and variables → Actions):
- `AWS_ROLE_ARN` — IAM role ARN for OIDC-based deployment
- `SMTP_USERNAME`, `SMTP_PASSWORD` — for failure notifications
- `NOTIFY_EMAIL` — alert recipient

**Environments** (Repo → Settings → Environments):
- Create `production` with required reviewers (manual approval gate)

### Tear Down

```bash
terraform destroy
```

## Architecture Decisions

### Why ECS Fargate over EC2 or EKS

**Picked Fargate because:** No server patching, no SSH key management, no node scaling decisions. AWS manages the underlying compute. Pay per task-second.

**Rejected EC2** because it's pre-AI-era ops overhead — you'd need AMI baking, autoscaling group tuning, AZ rebalancing, OS patching cycles. Not worth it for a containerized workload.

**Rejected EKS** because Kubernetes is the wrong abstraction unless you have 50+ services. Control plane alone costs $0.10/hour (~$73/month) before running any workloads. Overkill here.

### Why Multi-AZ

Production-grade availability without hedging. Single-AZ saves ~50% on NAT gateway cost but introduces a single point of failure that no SLA can excuse. Two AZs is the minimum credible setup.

### Why a Modular Terraform Layout

Each concern (VPC, security, RDS, ALB, ECS, secrets) lives in its own module. This:
- Forces clean interfaces (inputs, outputs) between layers
- Makes it possible to swap implementations (e.g., swap ECS for EKS) without touching networking
- Lets the team review changes per concern in PRs
- Mirrors how mature teams actually organize IaC

### Why Remote State (S3 + DynamoDB)

Local state files are a footgun in any team setting — lost laptop, accidental delete, two people running apply at once = corrupted infrastructure. S3 stores state with versioning (recovery), DynamoDB enforces locking (one writer at a time). Same pattern used in production at most enterprises.

## Security Considerations

### Network Layer

**Defense in depth via chained security groups:**

```
Internet → ALB SG (allows :80, :443 from 0.0.0.0/0)
       ↓
       ALB → ECS SG (allows app port from ALB SG only)
              ↓
              ECS → RDS SG (allows :5432 from ECS SG only)
```

Each layer accepts traffic only from the layer above. No direct internet → ECS, no direct internet → RDS. Compromising one layer doesn't grant access to the next.

**Public vs private subnets:**
- Public: only the ALB and NAT gateways. Nothing else faces the internet.
- Private: ECS tasks and RDS. Outbound internet via NAT only when required (image pulls, API calls).

### Identity & Access

**OIDC for CI/CD instead of long-lived AWS keys.** GitHub Actions assumes an IAM role via short-lived OIDC tokens (~1 hour validity). No `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` stored in GitHub Secrets — those are theft targets.

**Least-privilege IAM:**
- ECS task execution role: only ECR pull + CloudWatch Logs write + Secrets Manager read
- ECS task role: only what the application needs (extend per use case)
- GitHub deploy role: only ECR push + ECS service update

### Data Protection

**At rest:**
- RDS storage encryption: AES-256 (AWS-managed key)
- S3 state bucket encryption: AES-256
- ECR image encryption: AES-256
- Secrets Manager values: encrypted with AWS KMS

**In transit:**
- ALB supports HTTPS termination (add ACM cert + 443 listener for production)
- RDS connections inside VPC, no public exposure
- Secrets Manager API calls are TLS

**Credentials:**
- DB password stored in AWS Secrets Manager (not plaintext env vars)
- ECS tasks fetch secrets at startup via task execution role
- Secrets rotated independently of application deploys

### Application Security (Pipeline-Enforced)

**Trivy scans on every PR:**
- Filesystem scan catches CVEs in `package.json`, `requirements.txt`, etc.
- Container scan catches CVEs in base image and installed packages
- HIGH/CRITICAL severity blocks the merge

**Required PR review** via GitHub branch protection.

**Manual approval for production deploys** via GitHub Environments — an explicit human gate prevents pipeline-driven production incidents.

## Cost Optimization

Estimated idle cost in `ap-south-1`: **~$95-110/month** with current defaults.

### Where the Money Goes

| Resource | Monthly Cost | Notes |
|---|---|---|
| 2× NAT Gateway | ~$66 | $33 each, the largest single cost |
| RDS db.t4g.micro | ~$15 | Single-AZ, gp3 storage |
| Application Load Balancer | ~$20 | Plus LCU charges with traffic |
| ECS Fargate (2 tasks @ 0.5 vCPU, 1 GB) | ~$20 | Per task-second |
| Data transfer | Variable | First 1 GB free, then $0.09/GB |
| S3 + DynamoDB (state) | <$1 | Negligible |

### What's Already Optimized

- **Graviton (ARM) RDS instance** (`db.t4g.micro`) — ~20% cheaper than equivalent x86
- **gp3 storage** on RDS — ~20% cheaper than gp2 with better baseline IOPS
- **Fargate over EC2** — no idle compute when traffic is low
- **AWS-managed NAT gateways** instead of self-managed NAT instances — lower ops cost over the year, even if pricier per hour
- **Image pull caching** in CI/CD via GitHub Actions cache — faster builds, lower data transfer
- **Auto minor version upgrades** on RDS — security patches without manual cycles

### Optimization Levers If Cost Matters More

| Lever | Savings | Tradeoff |
|---|---|---|
| Single NAT gateway (one AZ) | -$33/mo | If that AZ fails, private subnets in the other AZ lose internet |
| RDS reserved instance (1yr) | ~30-40% | Lock-in, less flexibility |
| Aurora Serverless v2 instead of RDS | Variable | Scales to zero in dev; more expensive at high steady load |
| Fargate Spot | -70% on tasks | Tasks can be interrupted; not for prod APIs |
| VPC endpoints for S3/ECR | Eliminates NAT egress for those services | Costs ~$7/mo per endpoint, breaks even quickly at scale |

### What to Actually Do

- **For dev/staging:** drop to 1 NAT gateway. Saves $33/mo with acceptable risk.
- **For production:** keep both NATs. The downtime cost from a single-AZ NAT failure dwarfs $33/mo.
- **Always:** `terraform destroy` when done with non-prod environments. Idle cost adds up over weekends.

## Backup & Recovery

### What's Backed Up

**RDS automated backups:**
- Daily snapshots taken during `backup_window` (03:00-04:00 UTC = 08:30-09:30 IST)
- 7-day retention period
- Point-in-time recovery to any second within retention window
- Snapshots stored in separate AWS-managed S3 — survives RDS instance deletion (within retention)

**Terraform state:**
- S3 versioning enabled — every state change keeps prior versions
- Recovery: `aws s3api list-object-versions` then restore the prior version
- DynamoDB lock table prevents concurrent corruption

### What's Not Backed Up (And Why)

- **ECS tasks:** stateless. Failed tasks are replaced from the task definition.
- **ALB:** stateless. Recreated from Terraform.
- **VPC config:** declarative. Recreated from Terraform.

The only thing with state worth backing up is RDS data and the Terraform state itself.

### Recovery Procedures

**Restore RDS to a point in time:**

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-dev-postgres \
  --target-db-instance-identifier myapp-dev-postgres-restored \
  --restore-time 2026-05-07T14:30:00Z \
  --region ap-south-1
```

**Restore Terraform state from a prior version:**

```bash
# List versions
aws s3api list-object-versions \
  --bucket your-tfstate-ap-south-1 \
  --prefix app/terraform.tfstate

# Restore a specific version
aws s3api copy-object \
  --bucket your-tfstate-ap-south-1 \
  --copy-source "your-tfstate-ap-south-1/app/terraform.tfstate?versionId=VERSION_ID" \
  --key app/terraform.tfstate
```

## Common Operations

### Update the application

CI/CD handles this — push to `main` and staging deploys automatically. Production requires manual approval in GitHub Actions UI.

### Scale up/down

Edit `desired_count` in `terraform.tfvars`, then `terraform apply`.

### Rotate the database password

```bash
aws secretsmanager rotate-secret \
  --secret-id myapp-dev-db-credentials \
  --region ap-south-1
```

ECS tasks pick up the new value on next restart.

### Inspect logs

```bash
aws logs tail /ecs/myapp-dev --follow --region ap-south-1
```

## Known Limitations

- **No HTTPS listener configured.** ALB serves HTTP only. Add ACM cert + Route53 record + 443 listener for production.
- **Single-environment Terraform.** This stack deploys one environment at a time. For staging + prod, use Terraform workspaces or separate state keys (`app/staging/...`, `app/prod/...`).
- **No autoscaling on ECS.** Fixed task count. Add `aws_appautoscaling_target` + policy for traffic-based scaling.
- **No WAF.** ALB is unprotected from L7 attacks. Add `aws_wafv2_web_acl` for production.

These are explicit choices to keep the baseline minimal — not oversights. Production deployment should address them.

## Contact

Maintained by Biswajit. For issues, open a GitHub issue or contact via internal channels.