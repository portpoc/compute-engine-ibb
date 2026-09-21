# Compute IBB — Operational Runbook

- **Owner:** platform-engineering
- **Support:** #platform-support

## Support

Request help via the `#platform-support` Slack channel for anything time-sensitive, or open a
ticket in the platform-engineering support queue for non-urgent requests (schema questions,
property additions, new platform implementations). Include `requestId` and `correlationId` from
the failed request in either channel — the pipeline's uploaded `output.json`/`controls.json`
artifacts are keyed by `executionId`, which the run's Actions log links back to those IDs.

## Escalation

1. First point of contact: platform-engineering on-call via `#platform-support`.
2. If the failure is in the underlying AWS account (quota, API throttling, account-level policy
   denial) rather than in this IBB's own logic, escalate to the cloud platform team that owns the
   target AWS account.
3. Security-control failures surfaced by the post-apply verification step (`controls.json`
   showing `"result": "failed"`) escalate directly to platform-engineering — do not retry the
   same request without investigating; a retried `create` will provision a second, still
   non-compliant instance.

## Known failure modes

| Symptom | Likely cause | Recovery |
| :--- | :--- | :--- |
| `create` fails at `terraform plan` with an instance-type availability error | Requested `sizing.computeSize` is not offered in the target subnet's AZ | Resubmit `create` with a different `subnetId` (different AZ) or a supported `computeSize` for that AZ |
| `create` fails the policy gate citing `SBP AWS-005` | `image.osImageReference` resolves to an AMI owned outside the approved allow-list | Resubmit with an AMI owned by this org's own AMI account, `amazon`, or `aws-marketplace` |
| `create`/`update` fails with a VPC/subnet mismatch precondition error | `networking.subnetId` does not belong to `networking.networkId` | Verify the subnet's actual VPC (`aws ec2 describe-subnets`) and resubmit with a consistent pair |
| Post-apply verification reports `AWS-003` failed | `networking.publicIpEnabled` was requested `false` but the instance still received a public IP (e.g. subnet's own `map_public_ip_on_launch` default) | Use a subnet with `map_public_ip_on_launch = false`, or explicitly request `publicIpEnabled: true` if a public IP is actually intended |
| `delete` succeeds but the consumer's `resourceId` is later reused in a new request | Instance IDs are never reused by AWS, but a stale `context.resourceId` from a prior deleted instance will fail cleanly at `terraform apply -destroy` (resource already gone) | Confirm the instance was already deleted (`aws ec2 describe-instances`); no action needed — treat as already-terminal |

## Recovery procedures

- **create**: on `partially completed` status (a control failed post-apply but the instance
  exists), do not delete-and-retry automatically — investigate `controls.json` first, since the
  instance may simply need a follow-up `update` rather than replacement.
- **update**: re-run with `context.resourceId` set to the target instance; changes not covered by
  the exposed parameters (see the Technical Reference Design §12) require a manual change outside
  this IBB's current contract.
- **delete**: idempotent — deleting an already-deleted `resourceId` completes without error (see
  known failure modes above). The root EBS volume is destroyed with the instance; there is no
  automated recovery of instance data after `delete` completes.
- **validate**: never provisions anything; a `failed` validate result means the request itself is
  malformed or unauthorized, not that any resource needs cleanup.
