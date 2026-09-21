variable "request_id" {
  description = "request.requestId of the consumer request driving this apply; tagged onto the instance for traceability."
  type        = string
}

variable "correlation_id" {
  description = "context.correlationId of the consumer request; tagged onto the instance for traceability."
  type        = string
}

# sizing.*
variable "instance_type" {
  description = "sizing.computeSize — EC2 instance type, e.g. t3.medium."
  type        = string
}

variable "root_volume_size_gib" {
  description = "sizing.diskSizeGiB — size of the root EBS volume, GiB."
  type        = number

  validation {
    condition     = var.root_volume_size_gib >= 8
    error_message = "root_volume_size_gib must be >= 8, matching the shared dictionary's diskSizeGiB minimum."
  }
}

# networking.*
variable "vpc_id" {
  description = "networking.networkId — used only to validate subnet_id belongs to it."
  type        = string
}

variable "subnet_id" {
  description = "networking.subnetId — subnet the instance's primary ENI attaches to."
  type        = string
}

variable "associate_public_ip_address" {
  description = "networking.publicIpEnabled — defaults to false (SBP AWS-003)."
  type        = bool
  default     = false
}

# image.*
variable "ami_os_family" {
  description = "image.osFamily — linux or windows; selects the user_data bootstrap template."
  type        = string

  validation {
    condition     = contains(["linux", "windows"], var.ami_os_family)
    error_message = "ami_os_family must be 'linux' or 'windows'."
  }
}

variable "ami_id" {
  description = "image.osImageReference — AMI ID to launch. Must resolve to an approved-owner AMI (SBP AWS-005)."
  type        = string
}

# security.*
variable "admin_ssh_public_key" {
  description = "security.adminSshPublicKey — SSH public key material for the admin login account. Ignored for windows (SBP AWS-007: public key material only)."
  type        = string
  default     = null
}

variable "disk_encryption_enabled" {
  description = "security.diskEncryptionEnabled — requested value; the module always encrypts regardless (SBP AWS-002)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common resource tags (environment, applicationId, costCenter) supplied by the pipeline from context."
  type        = map(string)
  default     = {}
}
