# Compute — AWS Security Blueprint

- **Scope:** compute on aws
- **Paired Technical Reference Design:** `technical-reference-designs/aws/technical-reference-design-0.1.0.md`
- **Status:** draft
- **Owner:** platform-engineering

## Controls

| ID | Domain | Requirement | Priority | Rationale | Verification Method | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| AWS-001 | Platform Hardening | Instance Metadata Service v2 (IMDSv2) is enforced (`http_tokens = "required"`, `http_endpoint = "enabled"`) on every instance; IMDSv1 is disabled. | Critical | IMDSv1 is vulnerable to SSRF-based credential theft; EC2 instances routinely expose IAM role credentials via the metadata endpoint. | policy-as-code pre-apply (`policies/aws/aws-compute-0.1.0.rego`) + live-resource check post-apply (`aws ec2 describe-instances --query 'Reservations[].Instances[].MetadataOptions'`) | Implemented |
| AWS-002 | Data Protection | Root EBS volume is encrypted at rest (`encrypted = true`), regardless of the requested `security.diskEncryptionEnabled` value if that value is `false`. | Critical | Unencrypted root volumes leave instance data recoverable from a detached/snapshotted volume; encryption at rest is a non-negotiable baseline, not a consumer opt-out. | policy-as-code pre-apply (`policies/aws/aws-compute-0.1.0.rego`) + live-resource check post-apply (`aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=<id> --query 'Volumes[].Encrypted'`) | Implemented |
| AWS-003 | Network Security | `associate_public_ip_address` is `false` unless the request explicitly sets `networking.publicIpEnabled: true`; no other path assigns a public IP. | High | Public IPs on compute instances are the most common source of opportunistic internet-facing compromise; the default must be private-only. | policy-as-code pre-apply (`policies/aws/aws-compute-0.1.0.rego`) + live-resource check post-apply (`aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress'`) | Implemented |
| AWS-004 | Logging & Monitoring | Detailed instance monitoring is enabled (`monitoring = true`) on every instance, publishing the standard EC2 CloudWatch metric set. | High | Without this, CPU/network/disk metrics are only sampled every 5 minutes by default anyway in this case detailed monitoring narrows the same interval to 1 minute, giving operators a faster failure signal than the AWS default. | policy-as-code pre-apply (`policies/aws/aws-compute-0.1.0.rego`) + live-resource check post-apply (`aws ec2 describe-instances --query 'Reservations[].Instances[].Monitoring.State'`) | Implemented |
| AWS-005 | Supply Chain Security | `image.osImageReference` must resolve to an AMI owned by an approved account (this org's own AMI account or `amazon`/`aws-marketplace` with an explicit allow-list), never an arbitrary third-party AMI ID. | High | An unvetted AMI is an unvetted supply chain — it can carry backdoors, unpatched CVEs, or malicious startup scripts baked into the image itself. | policy-as-code pre-apply, checking `data.aws_ami.owner_id` for the resolved AMI against the allow-list in `policies/aws/aws-compute-0.1.0.rego` (`SEC-004`) | Implemented |
| AWS-006 | Identity & Access | The pipeline obtains AWS credentials via OIDC workload identity federation (`aws-actions/configure-aws-credentials`) scoped to a role permitting only the actions this capability needs; no static IAM access key is stored or used. | Critical | Long-lived static credentials are the highest-value target for lateral movement once a pipeline or its logs are compromised; OIDC federation issues short-lived, audience-scoped tokens instead. | reviewed at pipeline-authoring time (`pipelines/github-actions/compute-0.1.0.yml`); verified per-run by the absence of any `aws-access-key-id` secret reference in the workflow | Implemented |
| AWS-007 | Secrets Management | `security.adminSshPublicKey` is public key material only; the pipeline never accepts, stores, or logs a private key, and the request schema has no field that could carry one. | Critical | A private key transiting a pipeline (even transiently) or landing in run logs would need to be treated as compromised the moment it appears; the input contract structurally rules this out. | schema-level: `schemas/compute-input-0.1.0.schema.json` has no field for private key material; verified by `tests/check.sh` fixture validation rejecting any extra property under `additionalProperties: false` | Implemented |

## Verification

Controls above are:

1. **Implemented** in `iac/0.1.0/aws/` — each Terraform resource annotated with the control ID
   it satisfies (`# SBP AWS-001`), per `ART-005`.
2. **Verified pre-apply** by policy-as-code in `policies/aws/` (`SEC-004`).
3. **Verified post-apply** by the pipeline re-checking live resource state, not just the Terraform
   plan — a successful `apply` is not evidence of conformance on its own (`SEC-005`).
