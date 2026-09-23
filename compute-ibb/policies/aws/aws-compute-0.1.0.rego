package compute.aws

import rego.v1

# Policy-as-code gate run PRE-apply against the Terraform plan (terraform show -json). Each deny
# rule cites the Security Blueprint control ID it enforces so the pairing is auditable
# (security-blueprints/aws/security-blueprint-0.1.0.md).

instances := [rc | rc := input.resource_changes[_]; rc.type == "aws_instance"]

# SBP AWS-001 — IMDSv2 must be enforced; IMDSv1 must be disabled.
deny contains msg if {
	instance := instances[_]
	after := instance.change.after
	after.metadata_options[0].http_tokens != "required"
	msg := sprintf("SBP AWS-001: IMDSv2 must be enforced (metadata_options.http_tokens = \"required\") (%s)", [instance.address])
}

# SBP AWS-002 — root volume must be encrypted, regardless of the requested value.
deny contains msg if {
	instance := instances[_]
	after := instance.change.after
	not after.root_block_device[0].encrypted
	msg := sprintf("SBP AWS-002: root_block_device.encrypted must be true (%s)", [instance.address])
}

# SBP AWS-003 — no public IP unless explicitly requested; deny when a public IP was NOT
# requested by the caller but the plan would still associate one (defense in depth against a
# Terraform module regression, since the module itself already defaults this to false).
deny contains msg if {
	instance := instances[_]
	after := instance.change.after
	after.associate_public_ip_address == true
	requested_public_ip == false
	msg := sprintf("SBP AWS-003: associate_public_ip_address must be false unless networking.publicIpEnabled was requested (%s)", [instance.address])
}

requested_public_ip := value if {
	value := input.variables.associate_public_ip_address.value
} else := false

# SBP AWS-004 — detailed instance monitoring must be enabled.
deny contains msg if {
	instance := instances[_]
	after := instance.change.after
	after.monitoring != true
	msg := sprintf("SBP AWS-004: monitoring must be true (1-minute detailed CloudWatch metrics) (%s)", [instance.address])
}

# SBP AWS-005 — the resolved AMI must be owned by an approved account: this org's own AMI
# account, or the public `amazon` / `aws-marketplace` owners.
approved_ami_owners := {"self", "amazon", "aws-marketplace"}

deny contains msg if {
	ami := input.resource_changes[_]
	ami.type == "aws_ami"
	owner := ami.change.after.owner
	not owner in approved_ami_owners
	msg := sprintf("SBP AWS-005: AMI owner '%s' is not on the approved owner allow-list (self, amazon, aws-marketplace) (%s)", [owner, ami.address])
}
