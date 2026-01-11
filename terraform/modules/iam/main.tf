# IAM Role for EC2 with SSM access
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.name_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ec2-ssm-role"
  }
}

# Attach SSM Managed Instance Core policy
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch Agent policy for logging (optional but useful)
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm.name
}
