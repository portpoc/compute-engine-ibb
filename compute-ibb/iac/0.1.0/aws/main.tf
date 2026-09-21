# SBP AWS-005 — resolve and validate the requested AMI belongs to an approved owner before use.
# The policy-as-code gate (policies/aws/aws-compute-0.1.0.rego) additionally denies at plan time
# if the resolved owner is not on the allow-list; this data source is what it reads.
data "aws_ami" "requested" {
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

data "aws_subnet" "target" {
  id = var.subnet_id
}

resource "aws_key_pair" "this" {
  count      = var.ami_os_family == "linux" && var.admin_ssh_public_key != null ? 1 : 0
  key_name   = "compute-${var.request_id}"
  public_key = var.admin_ssh_public_key
}

# SBP AWS-001 — IMDSv2 enforced, IMDSv1 disabled.
# SBP AWS-002 — root volume always encrypted, independent of the requested value.
# SBP AWS-003 — no public IP unless explicitly requested.
# SBP AWS-004 — detailed (1-minute) instance monitoring enabled.
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.ami_os_family == "linux" ? try(aws_key_pair.this[0].key_name, null) : null
  monitoring                  = true

  lifecycle {
    precondition {
      condition     = data.aws_subnet.target.vpc_id == var.vpc_id
      error_message = "subnet_id ${var.subnet_id} does not belong to vpc_id ${var.vpc_id}."
    }
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = var.root_volume_size_gib
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name          = "compute-${var.request_id}"
    RequestId     = var.request_id
    CorrelationId = var.correlation_id
    ManagedBy     = "compute-ibb"
  })
}
