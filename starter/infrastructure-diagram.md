# Udagram Infrastructure Diagram

```mermaid
flowchart TB
    Internet((Internet))
    S3[(S3 static content bucket)]

    subgraph VPC[Udagram VPC]
        IGW[Internet Gateway]

        subgraph AZ1[Availability Zone 1]
            subgraph Public1[Public Subnet 1]
                NAT1[NAT Gateway 1]
            end
            subgraph Private1[Private Subnet 1]
                EC2A[EC2 instance 1]
                EC2B[EC2 instance 2]
            end
        end

        subgraph AZ2[Availability Zone 2]
            subgraph Public2[Public Subnet 2]
                NAT2[NAT Gateway 2]
            end
            subgraph Private2[Private Subnet 2]
                EC2C[EC2 instance 3]
                EC2D[EC2 instance 4]
            end
        end

        ALB[Internet-facing Application Load Balancer\nattached to both public subnets]
        ALBSG[ALB security group\nHTTP 80 from 0.0.0.0/0]
        WebSG[Web server security group\nHTTP 80 from ALB only]
        ASG[Auto Scaling Group\nmin 4 / desired 4 / max 4]
    end

    Internet -->|HTTP 80| IGW
    IGW -->|Public route| ALB
    IGW -->|Public route| NAT1
    IGW -->|Public route| NAT2

    ALB -.->|Inbound rule| ALBSG
    ALBSG -.->|Load-balanced HTTP 80| ALB
    Public1 -.->|ALB subnet attachment| ALB
    Public2 -.->|ALB subnet attachment| ALB
    ALB -->|Target group / health checks| ASG
    ASG --> EC2A
    ASG --> EC2B
    ASG --> EC2C
    ASG --> EC2D

    WebSG -.->|Inbound rule| EC2A
    WebSG -.->|Inbound rule| EC2B
    WebSG -.->|Inbound rule| EC2C
    WebSG -.->|Inbound rule| EC2D

    NAT1 -->|Private route| EC2A
    NAT1 -->|Private route| EC2B
    NAT2 -->|Private route| EC2C
    NAT2 -->|Private route| EC2D

    EC2A -->|IAM role: read/write| S3
    EC2B -->|IAM role: read/write| S3
    EC2C -->|IAM role: read/write| S3
    EC2D -->|IAM role: read/write| S3
    S3 -->|Static page pulled at launch| ASG
```

## Traffic and content flow

- Public HTTP traffic enters through the Internet Gateway and reaches the internet-facing Application Load Balancer.
- The load balancer forwards requests to healthy nginx servers in the private subnets through the Auto Scaling Group.
- Private instances use their Availability Zone's NAT Gateway for outbound software updates and package installation.
- Each instance uses its IAM role to read the static website content from the S3 bucket. The bucket also grants the required read/write permissions to the instance role.
- The two public and two private subnets are distributed across separate Availability Zones for high availability.
