output "nlb_dns_name" {
  description = "DNS name of the NLB"
  value       = aws_lb.main.dns_name
}

output "nlb_arn" {
  description = "ARN of the NLB"
  value       = aws_lb.main.arn
}

output "dashboard_target_group_arn" {
  description = "ARN of the dashboard target group"
  value       = aws_lb_target_group.dashboard.arn
}

output "agent_events_target_group_arn" {
  description = "ARN of the agent events target group"
  value       = aws_lb_target_group.agent_events.arn
}

output "agent_registration_target_group_arn" {
  description = "ARN of the agent registration target group"
  value       = aws_lb_target_group.agent_registration.arn
}

output "target_group_arns" {
  description = "List of all target group ARNs"
  value = [
    aws_lb_target_group.dashboard.arn,
    aws_lb_target_group.agent_events.arn,
    aws_lb_target_group.agent_registration.arn
  ]
}
