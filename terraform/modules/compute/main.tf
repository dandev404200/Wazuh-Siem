# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]  # Excludes minimal AMI
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "wazuh" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Commented out for manual installation - uncomment after testing
  # user_data = base64encode(templatefile("${path.module}/user-data.sh", {
  #   wazuh_version = var.wazuh_version
  # }))

  tags = {
    Name = "${var.name_prefix}-server"
  }

  # Ensure instance is replaced if user-data changes
  lifecycle {
    create_before_destroy = true
  }
}
