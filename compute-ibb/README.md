# Compute IBB

A technology-agnostic **Compute** capability, delivered as an Infrastructure Building
Block: Technical Reference Design + Security Blueprint + Infrastructure-as-Code + Deployment Pipeline,
bound together by [`ibb-manifest.yaml`](./ibb-manifest.yaml).

- **Owner:** platform-engineering
- **Support:** #platform-support
- **Status:** draft — not yet released; see [`CHANGELOG.md`](./CHANGELOG.md)

## What this capability is

Provisions a single virtual machine instance — sized, imaged, networked and secured according to
the agnostic parameters below — without a consumer needing to know which cloud provider's compute
service backs it. A consumer requests a compute size, disk size, network placement, OS family/image
and access-credential/encryption posture, and gets back a running instance and its operational
state.

## Supported implementations

| Platform | Reference Design | Security Blueprint |
| :--- | :--- | :--- |
| aws | [reference design](./technical-reference-designs/aws/technical-reference-design-0.1.0.md) | [security blueprint](./security-blueprints/aws/security-blueprint-0.1.0.md) |

## Supported operations

- `validate` — dry-runs a request (schema, version/platform, authorization checks) without provisioning anything.
- `create` — provisions a new compute instance.
- `update` — changes an existing instance's configuration (e.g. resize, disk size, network placement).
- `delete` — terminates and deprovisions the instance.

## Consuming this IBB

Consumers call the pipeline in [`pipelines/`](./pipelines/) with the mandatory context and the agnostic parameters defined in [`schemas/compute-input-0.1.0.schema.json`](./schemas/compute-input-0.1.0.schema.json).
See [`examples/`](./examples/) for minimal runnable requests per platform.

Consumers pin an explicit `context.buildingBlockVersion`.

## Properties

### sizing

Compute capacity and disk sizing properties for provisioned resources.

| Parameter | Values | Meaning |
| :--- | :--- | :--- |
| `computeSize` | string | Provider-specific compute size/instance type (e.g. AWS EC2 instance type such as `t3.medium`). |
| `diskSizeGiB` | integer, minimum 8 | Size, in GiB, of the primary/root disk attached to the compute resource. |

### networking

Network placement and connectivity properties for provisioned resources.

| Parameter | Values | Meaning |
| :--- | :--- | :--- |
| `region` | string | Provider region the resource is placed into (AWS region such as `eu-west-1`). |
| `networkId` | string | Identifier of the virtual network the resource is placed into (AWS VPC ID). |
| `subnetId` | string | Identifier of the subnet the resource's primary network interface attaches to. |
| `publicIpEnabled` | boolean | Whether the resource is assigned a public/internet-routable IP address. |

### image

Operating system image/family properties for provisioned compute resources.

| Parameter | Values | Meaning |
| :--- | :--- | :--- |
| `osFamily` | `linux` \| `windows` | Broad OS family of the image, used to select platform-appropriate defaults (SSH vs. RDP access, agent bootstrap script). |
| `osImageReference` | string | Provider-specific image reference (AWS AMI ID) used to launch the compute resource. |

### security

Access-credential and encryption properties for provisioned resources.

| Parameter | Values | Meaning |
| :--- | :--- | :--- |
| `adminSshPublicKey` | string | SSH public key material installed for the resource's administrative/login account (Linux instances). |
| `diskEncryptionEnabled` | boolean | Whether the resource's attached disks are encrypted at rest using the provider's default or a customer-managed key. |

All properties above are drawn from the shared [`iac-ibb-dictionary`](ssh://git@bitbucket.dsv.com:7999/transform/iac-ibb-dictionary.git)
at `master`, already tagged `usedBy: [compute]`, with one exception: `networking.region` was added
to the dictionary for this capability via [PR #3](https://bitbucket.dsv.com/projects/TRANSFORM/repos/iac-ibb-dictionary/pull-requests/3)
and is provisional until that PR merges.

## Dependencies

_None._

## Self-service

Consumers without direct pipeline access request `create`/`update`/`delete` through the
`compute-lifecycle` Port.io workflow (Port catalog). `validate` is pipeline-only and has no
self-service outlet, per convention. The workflow currently dispatches to a `compute-ibb` GitHub
repo via the `github-ocean` integration with a placeholder `owner` — set the real org before
relying on it, and note it still has the known gap that it expects the request JSON file to be
pre-committed at `requests/<request_id>.json` rather than writing it from the form.

## Contributing

Write access is gated by [`CODEOWNERS`](./CODEOWNERS). Trunk-based, small PRs, conventional commits.
See [`docs/runbook.md`](./docs/runbook.md) for support and escalation.
