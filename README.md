# DevOps Senior Assignment — Customer Engagement Platform

Section 1: Infrastructure Design, Cost Optimization & IaC.

A highly available, autoscaling, cost-optimized AWS architecture for a customer
engagement platform with campaign-driven traffic spikes — implemented as
Terraform.

## Deliverables

| Deliverable | File |
|-------------|------|
| Architecture diagram | [`architecture.drawio`](architecture.drawio) (Draw.io) + [`architecture.md`](architecture.md) (Mermaid) |
| Design document (decisions, trade-offs, security, cost) | [`DESIGN.md`](DESIGN.md) |
| Infrastructure as Code | [`terraform/`](terraform/) |

## Architecture at a glance

**ECS Fargate** (serverless containers, FARGATE + FARGATE_SPOT, ARM64) behind an
**ALB + WAF**, autoscaling on CPU / ALB request-count with scheduled off-hours
downscaling, backed by **RDS PostgreSQL (Multi-AZ)** with an **ElastiCache Redis**
cache-aside layer — all in private subnets across 3 AZs, provisioned by Terraform.

See [`DESIGN.md`](DESIGN.md) for why ECS Fargate over EKS / Lambda / EC2, and the
cost + security rationale.

## What the Terraform creates

- **VPC** — public/private subnets across 3 AZs, IGW, NAT, route tables, Flow Logs
- **ECS Fargate** — cluster, task definition (Graviton), service, FARGATE +
  FARGATE_SPOT capacity providers
- **Auto Scaling** — CPU + ALB RPS target tracking, scheduled off-hours floor
- **ALB** — HTTP→HTTPS redirect, ACM listener, IP target group
- **WAF** — AWS managed rules + per-IP rate limiting
- **RDS** — PostgreSQL Multi-AZ, encrypted, gp3 storage autoscaling
- **ElastiCache** — Redis Multi-AZ, encryption at rest + in transit
- **S3 + CloudFront** — private encrypted assets bucket (OAC), CDN fronting ALB
  (dynamic) + S3 (`/static/*`, edge-cached)
- **IAM** — least-privilege execution + task roles
- **Security groups** — tiered internet → ALB → ECS → RDS/Redis
- **Secrets Manager** — generated DB credentials, injected at runtime

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit as needed
terraform init
terraform plan
terraform apply
```

Requires: Terraform >= 1.5, AWS credentials with permission to create the above.
Validated with `terraform validate` (no backend required to init locally).

After apply, `terraform output alb_dns_name` gives the public endpoint.

## Notes for reviewers

- Defaults favor a quick, low-cost demo (single NAT, HTTP-only if no ACM cert,
  `skip_final_snapshot`). Comments mark each `# set ... in prod` toggle.
- The application image defaults to public nginx so the stack stands up without a
  custom image; swap `container_image` for the real service.
- Multi-region DR is described in `DESIGN.md` and the diagram; the modules are
  region-parameterized so the same code deploys the standby region.
