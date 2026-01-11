variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., poc, dev, prod)"
  type        = string
  default     = "poc"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "wazuh"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnets"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type for Wazuh server"
  type        = string
  default     = "t3.xlarge"
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 100
}

variable "wazuh_version" {
  description = "Wazuh version to deploy"
  type        = string
  default     = "4.9.0"
}
