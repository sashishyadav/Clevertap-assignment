# Design Document — Customer Engagement Platform on AWS

**Author:** Ramashish
**Scope:** Section 1 — Infrastructure Design, Cost Optimization & IaC

---

## 1. Problem recap

A customer engagement platform serving millions of users, with **sudden traffic
spikes during promotional campaigns** and quiet **off-hours**. The existing setup
is manually-provisioned EC2 in a single region: unscalable, expensive, drift-prone,
and weak on security. Goals: HA (multi-region), **≥30% cost reduction**, security
best practices, and fully **automated provisioning**.

## 2. Chosen architecture — ECS Fargate

```
        Route 53 (failover routing to DR region)
                     │
             CloudFront + AWS WAF
                     │
                    ALB          (public subnets, 3 AZs, HTTPS/ACM)
                     │
          ECS Fargate service     (private subnets, 3 AZs)
          FARGATE + FARGATE_SPOT
          autoscaling: CPU + ALB RPS + scheduled off-hours
              │                     │
     ElastiCache Redis        RDS PostgreSQL
     (cache-aside, Multi-AZ)  (Multi-AZ, encrypted)
```

**Compute — ECS on Fargate.** Serverless containers: no EC2 fleet to patch or
right-size, scales per-task, and scales to a near-zero floor off-hours. A
capacity-provider strategy mixes on-demand `FARGATE` (a stable base of 1 task)
with `FARGATE_SPOT` (~70% cheaper) for everything above the base. Tasks run on
**Graviton/ARM64** for a further ~20% price/performance gain.

**Storage & caching — RDS PostgreSQL + ElastiCache Redis + S3.** RDS gives
relational integrity for user/engagement data with Multi-AZ failover and storage
autoscaling. ElastiCache sits in front as a **cache-aside** layer so campaign read
spikes are absorbed in memory and never reach the database. S3 (referenced in the
design; add as needed) holds static assets served via CloudFront.

**Networking & security.** A VPC with public subnets (ALB, NAT) and private
subnets (ECS, RDS, Redis) across 3 AZs. Layered security groups allow traffic only
from the tier directly in front: internet → ALB → ECS → (RDS, Redis). WAF (AWS
managed rules + per-IP rate limiting) fronts the ALB. Encryption at rest (RDS,
Redis, secrets) and in transit (TLS 1.2/1.3 on the ALB, transit encryption on
Redis). Credentials are generated and stored in Secrets Manager — never in code or
images. VPC Flow Logs provide network auditability.

**CI/CD.** GitHub Actions with OIDC federation to a scoped IAM role (no long-lived
keys). Pipeline: `fmt` / `validate` / `tflint` → `terraform plan` on PR (posted as a
comment) → manual approval → `apply` on merge to `main`. Application image builds
push to ECR and trigger an ECS rolling deploy with the deployment circuit breaker
enabled for automatic rollback.

## 3. Why Terraform (not CloudFormation)

- **Cloud-agnostic & portable** — one tool/language if we ever add another provider
  or SaaS (Cloudflare, Datadog).
- **Module ecosystem & state** — reusable modules, remote state with locking, and a
  readable `plan` diff before every change.
- **Team familiarity & tooling** — `tflint`, `checkov`, `terraform-docs`, Atlantis.

CloudFormation is a fine AWS-native alternative (no state file to manage, native
drift detection), but its verbosity and AWS-only lock-in make Terraform the better
fit here.

## 4. Trade-offs — alternatives considered and rejected

| Option | Why not chosen |
|--------|----------------|
| **EKS (Kubernetes)** | Best for large multi-team orgs needing K8s portability. But it adds a control-plane cost and heavy operational surface (node groups, Karpenter, IRSA, add-on lifecycle). For a single platform this is **over-engineering** and risks an incomplete, harder-to-review IaC deliverable. ECS Fargate gives the same container benefits with far less to operate. |
| **Lambda + API Gateway + DynamoDB (serverless)** | Genuinely the **lowest-cost** option for purely spiky, event-driven request/response traffic (scales to $0 off-hours, instant burst). Rejected as the *primary* design because: cold starts hurt latency-sensitive paths, a 15-min execution ceiling and vendor lock-in constrain long-running/stateful work (e.g. websockets for live engagement), and it maps awkwardly onto the required ALB + autoscaling-group + RDS building blocks. **Recommended as the next step** for isolated event-driven endpoints. |
| **Raw EC2 + Auto Scaling Groups** | The closest to the current setup and cheapest per-vCPU at steady load, but you own AMI baking, patching, and OS security. Higher ops burden with no offsetting benefit for a containerized app. |
| **Fargate-only (no Spot)** | Simplest, but forfeits the ~70% Spot discount that drives the cost target. The Spot+on-demand mix keeps availability (stable base) while capturing most of the savings. |

**Summary:** ECS Fargate is the best balance of low ops overhead, strong cost
story, full HA, and clean mapping to the required building blocks — without EKS's
complexity or Lambda's constraints.

## 5. Cost optimization (targeting ≥30%)

1. **Fargate Spot** for burst capacity — up to ~70% off on-demand.
2. **Graviton/ARM64** tasks and `t4g`/Graviton DB & cache instances — ~20% cheaper.
3. **Scheduled scaling** — floor drops to 1 task off-hours; no campaign-sized
   capacity billed at 3 AM.
4. **Autoscaling** on CPU + ALB request count — pay for capacity only while the
   spike lasts, then scale back in.
5. **Cache-aside** — Redis absorbs reads so RDS can stay a smaller instance.
6. **Single NAT gateway** in non-prod (toggleable) and **gp3 + storage
   autoscaling** so we don't over-provision disk.
7. **Right-sizing** via Container Insights / Compute Optimizer feedback loop.

Combined, Spot + scheduled off-hours downscaling + Graviton comfortably exceed the
30% target versus a statically-provisioned 24/7 fleet sized for peak.

## 6. High availability & DR

- **Within region:** 3 AZs for ALB, ECS tasks, RDS Multi-AZ, and Redis Multi-AZ.
- **Multi-region (DR):** Route 53 failover routing to a warm-standby stack in a
  second region, with a cross-region RDS read replica (promotable), cross-region
  ECR replication, and S3 CRR. The Terraform is written region-parameterized so the
  same modules deploy the DR region. Active-active (Route 53 latency routing) is a
  further step, traded off against higher cost/complexity.

## 7. Security checklist

- [x] Private subnets for all compute and data tiers
- [x] Least-privilege security groups (tier-to-tier only)
- [x] Least-privilege IAM (scoped execution + task roles; secret-scoped policies)
- [x] WAF with managed rules + rate limiting
- [x] Encryption at rest (RDS, Redis, Secrets Manager) and in transit (TLS, Redis)
- [x] No hard-coded secrets — generated + Secrets Manager, injected at runtime
- [x] VPC Flow Logs for audit
- [x] CI/CD via OIDC (no static cloud credentials)
