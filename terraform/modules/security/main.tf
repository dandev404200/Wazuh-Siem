# Security Group for EC2 instance
resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Security group for Wazuh EC2 instance"
  vpc_id      = var.vpc_id

  # Dashboard HTTPS (NLB passthrough - NLB preserves source IP)
  ingress {
    description = "Dashboard HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Agent events (NLB passthrough)
  ingress {
    description = "Agent events"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Agent registration (NLB passthrough)
  ingress {
    description = "Agent registration"
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Wazuh API from VPC
  ingress {
    description = "Wazuh API from VPC"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound (for SSM, Docker pulls, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ec2-sg"
  }
}
