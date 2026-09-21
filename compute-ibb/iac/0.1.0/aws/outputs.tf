output "resource_id" {
  description = "result.resourceId — EC2 instance ID."
  value       = aws_instance.this.id
}

output "operational_state" {
  description = "result.operationalState — EC2 instance state (e.g. running, stopped)."
  value       = aws_instance.this.instance_state
}

output "private_ip_address" {
  description = "result.privateIpAddress"
  value       = aws_instance.this.private_ip
}

output "public_ip_address" {
  description = "result.publicIpAddress — empty when networking.publicIpEnabled was not requested."
  value       = aws_instance.this.public_ip
}

output "availability_zone" {
  description = "result.availabilityZone"
  value       = aws_instance.this.availability_zone
}
