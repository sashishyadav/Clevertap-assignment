# Architecture Diagram

Rendered Mermaid below (viewable on GitHub / any Mermaid viewer). A Draw.io-
importable file is provided as `architecture.drawio` for the formal deliverable.

## Primary region topology

```mermaid
flowchart TB
    user([Users / Millions])
    dns[Route 53<br/>failover routing]
    cdn[CloudFront + WAF]

    user --> dns --> cdn

    subgraph REGION["AWS Region (primary) — VPC 10.0.0.0/16"]
        direction TB

        subgraph PUB["Public subnets (3 AZs)"]
            alb[Application Load Balancer<br/>HTTPS / ACM]
            nat[NAT Gateway]
        end

        subgraph PRIV["Private subnets (3 AZs)"]
            subgraph ECS["ECS Fargate service"]
                t1[Task<br/>FARGATE base]
                t2[Task<br/>FARGATE_SPOT]
                t3[Task<br/>FARGATE_SPOT]
            end
            redis[(ElastiCache Redis<br/>Multi-AZ, cache-aside)]
            rds[(RDS PostgreSQL<br/>Multi-AZ, encrypted)]
        end

        cdn --> alb
        alb --> t1
        alb --> t2
        alb --> t3
        t1 --> redis
        t2 --> redis
        t3 --> redis
        t1 --> rds
        t2 --> rds
        t3 --> rds
        redis -.cache miss.-> rds

        sm[Secrets Manager<br/>DB creds]
        t1 -.reads secret.-> sm

        asg[[Application Auto Scaling<br/>CPU + ALB RPS + scheduled]]
        asg -.scales.-> ECS
    end

    subgraph DR["AWS Region (DR) — warm standby"]
        rds2[(RDS cross-region<br/>read replica)]
    end

    rds -.async replication.-> rds2
    dns -.failover.-> DR
```

## Autoscaling & cost flow (campaign vs off-hours)

```mermaid
flowchart LR
    A[Traffic spike<br/>promo campaign] --> B{Auto Scaling}
    B -->|CPU > 60%| C[Add tasks]
    B -->|ALB RPS > 1000/task| C
    C --> D[Mostly FARGATE_SPOT<br/>~70% cheaper]
    E[Off-hours 20:00 UTC] --> F[Scheduled action<br/>floor -> 1 task]
    F --> G[Near-zero idle cost]
    D --> H[Scale in after spike<br/>cooldown 300s]
```
