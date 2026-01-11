output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.wazuh.id
}

output "private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.wazuh.private_ip
}
