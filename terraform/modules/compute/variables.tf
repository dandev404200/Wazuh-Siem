variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
}

variable "private_subnet_id" {
  description = "ID of the private subnet"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group"
  type        = string
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile"
  type        = string
}

variable "wazuh_version" {
  description = "Wazuh version to deploy"
  type        = string
}

variable "nlb_target_group_arns" {
  description = "List of NLB target group ARNs"
  type        = list(string)
  default     = []
}
