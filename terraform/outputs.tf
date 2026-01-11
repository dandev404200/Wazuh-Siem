output "nlb_dns_name" {
  description = "NLB DNS name for external agent connectivity and dashboard access"
  value       = module.nlb.nlb_dns_name
}

output "ec2_private_ip" {
  description = "EC2 private IP for internal agent connectivity"
  value       = module.compute.private_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID (use with SSM: aws ssm start-session --target <id>)"
  value       = module.compute.instance_id
}

output "dashboard_url" {
  description = "Wazuh Dashboard URL"
  value       = "https://${module.nlb.nlb_dns_name}"
}

output "agent_registration_address" {
  description = "Address for external agent registration"
  value       = "${module.nlb.nlb_dns_name}:1515"
}

output "agent_events_address" {
  description = "Address for external agent events"
  value       = "${module.nlb.nlb_dns_name}:1514"
}

output "internal_agent_address" {
  description = "Address for internal (VPC) agent connectivity"
  value       = "${module.compute.private_ip}:1514"
}

output "ssm_connect_command" {
  description = "Command to connect via SSM"
  value       = "aws ssm start-session --target ${module.compute.instance_id}"
}
