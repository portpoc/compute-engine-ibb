# Compute — AWS Technical Reference Design

- **Capability:** compute
- **Platform:** aws
- **Owning IBB:** compute@0.1.0
- **TRD version:** 0.1.0
- **Status:** draft
- **Owner:** platform-engineering

## 1. Identity

Capability `compute`, platform `aws`, owning IBB `compute@0.1.0`, TRD version `0.1.0`, status
`draft`, owner `platform-engineering`.

## 2. Selected technology

**Amazon EC2** (`aws_instance` in the AWS Terraform provider). EC2 is the direct, general-purpose
mapping for an agnostic "compute instance" capability on AWS: it exposes exactly the knobs this
capability's contract needs (instance type, root volume size/encryption, VPC/subnet placement,
public IP association, AMI, SSH key) without requiring a higher-level orchestration layer (ECS,
EKS, Lambda) that would change the consumption model. Alternatives considered and rejected for
this capability: Auto Scaling Groups (deferred — out of scope for a single-instance `compute`
capability; a future `compute-fleet` capability could build on this one), Lightsail (too
constrained for VPC/subnet placement control required by requirement mapping).

## 3. Architecture and components

```
consumer request
      │
      ▼
 pipeline (github-actions)
      │  requirementMapping.aws.* → terraform vars
      ▼
 iac/0.1.0/aws (Terraform)
   ├── aws_instance.this            (the EC2 instance)
   ├── aws_key_pair.this            (imports adminSshPublicKey, linux only)
   ├── data.aws_ami / passthrough   (osImageReference resolves directly to an AMI ID)
   └── root_block_device { ... }   (diskSizeGiB, diskEncryptionEnabled)
      │
      ▼
 EC2 instance running in the consumer-specified VPC/subnet
```

No load balancer, ASG, or DNS record is created by this capability — those are separate
capabilities a solution composes on top of `compute`.

## 4. Network topology

The instance's single ENI is attached to the `networking.subnetId` supplied by the consumer,
inside the `networking.networkId` (VPC) that subnet belongs to — this capability does not create
network infrastructure, it only places the instance into network infrastructure the consumer
already owns. `networking.publicIpEnabled` controls `associate_public_ip_address`; when `false`
(the default posture recommended in the Security Blueprint), the instance is reachable only from
within the VPC or via a bastion/SSM Session Manager, never directly from the internet. DNS
resolution for the instance is the consumer's own VPC's responsibility (Route 53 private zones,
if any) — not provisioned here.

## 5. Configuration model

Every parameter exposed to the consumer is listed in `ibb-manifest.yaml`'s
`requirementMapping.aws`, one Terraform variable per agnostic property:

| Agnostic property | Terraform variable | Notes |
| :--- | :--- | :--- |
| `sizing.computeSize` | `instance_type` | Any valid EC2 instance type string, e.g. `t3.medium`. |
| `sizing.diskSizeGiB` | `root_block_device.volume_size` | Minimum 8 per the shared dictionary. |
| `networking.networkId` | `vpc_id` | Used only to validate `subnet_id` belongs to it; EC2 itself takes only the subnet. |
| `networking.subnetId` | `subnet_id` | |
| `networking.publicIpEnabled` | `associate_public_ip_address` | Defaults to `false` if omitted. |
| `image.osFamily` | `ami_os_family_tag` | Drives which bootstrap `user_data` template is rendered (SSH vs. RDP surface). |
| `image.osImageReference` | `ami_id` | Consumer-supplied AMI ID; must exist in-region (SBP AWS-005). |
| `security.adminSshPublicKey` | `key_pair.public_key` | Linux only; ignored (with a warning) for `osFamily: windows`. |
| `security.diskEncryptionEnabled` | `root_block_device.encrypted` | Defaults to `true`; the policy gate denies `false` (SBP AWS-002). |

Approved default not exposed to the consumer: `metadata_options.http_tokens = "required"`
(IMDSv2-only), always applied regardless of request content (SBP AWS-001).

## 6. Availability and resilience

A single EC2 instance has no built-in failover — this capability provisions exactly one instance
per `create` request, matching a "single compute instance" contract. Availability is the
consumer's responsibility to compose (e.g. by requesting multiple instances behind a
separately-owned load-balancing capability, or by pairing with an Auto Scaling capability once
one exists). AWS's underlying EC2 SLA and the chosen instance's hardware placement are the only
resilience characteristics in scope here.

## 7. Backup and recovery

Root volume backup is out of scope for `create`/`update`/`delete`; `diskEncryptionEnabled` covers
data-at-rest protection but not durability. Consumers requiring point-in-time recovery should pair
this capability with a separate snapshot/backup capability once available. On `delete`, the root
EBS volume is destroyed together with the instance (`delete_on_termination = true`) — this is a
destructive, non-recoverable operation and is documented as such in the runbook.

## 8. Observability integration

Instance-level CloudWatch monitoring (`monitoring = true`, the standard 5-minute metric set) is
enabled unconditionally on every instance this capability creates (SBP AWS-004). No custom
CloudWatch agent, log group, or dashboard is provisioned by this capability itself; log shipping is
the responsibility of the AMI's baked-in agent configuration (out of this capability's control
surface) or a future logging capability.

## 9. Required integrations

- **Identity:** the pipeline authenticates to AWS via OIDC workload identity federation
  (`aws-actions/configure-aws-credentials`), never a static access key (SBP AWS-006).
- **Networking:** consumes a VPC/subnet the consumer already owns (see §4) — this capability has
  no dependency on another IBB for that; `dependencies: []` in `ibb-manifest.yaml`.
- **Key management:** none beyond the consumer-supplied SSH public key material; EBS default
  encryption uses the account's default AWS-managed KMS key unless a future version adds a
  customer-managed-key parameter.

## 10. Platform-specific constraints

- Instance type must be available in the target region/AZ; a `create` can fail at `apply` time if
  the requested `computeSize` is not offered in that AZ — the pipeline surfaces this as a `failed`
  status with `error.category: execution`, not a schema validation error.
- AMI (`osImageReference`) must exist in the same region as the target subnet; cross-region AMI
  IDs fail at plan/apply time.
- EBS `gp3` volumes (the default root volume type this capability provisions) have an 8 GiB
  minimum, matching the shared dictionary's `diskSizeGiB` minimum exactly.

## 11. Consumption interface

A solution never talks to EC2 directly. It calls this IBB's pipeline with a `create` request
carrying `sizing`, `networking`, `image`, and (for Linux) `security.adminSshPublicKey`. On success
(`status: completed`), `result.resourceId` is the EC2 instance ID (`i-...`), `result.operationalState`
mirrors the instance's `aws_instance.this.instance_state`, and `result.privateIpAddress` /
`result.publicIpAddress` (when requested) / `result.availabilityZone` are populated from Terraform
outputs (`outputs.tf`). A subsequent `update` or `delete` targets that same `resourceId` via
`context.resourceId`. There is no direct SSH/RDP handoff from this capability — connectivity is via
whatever the consumer's own network path to the subnet already provides.

## 12. Operational responsibilities

The `compute` IBB team (platform-engineering) operates: the Terraform module, the pipeline, the
policy gate, and the AMI/instance-type compatibility contract. The consuming solution operates:
everything running inside the instance (OS patching beyond the base AMI, application deployment,
in-guest configuration) and the network path to reach it. Instance termination protection is off
by default; a solution that wants `disable_api_termination = true` must request it via a future
`update` once that knob is exposed (not in this 0.1.0 property set).

## 13. Traceability

- Paired Security Blueprint: `security-blueprints/aws/security-blueprint-0.1.0.md`
- IaC implementation: `iac/0.1.0/aws`
- Pipeline logic: `pipelines/github-actions/compute-0.1.0.yml`
