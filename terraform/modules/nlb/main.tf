# Network Load Balancer
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [var.public_subnet_id]

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.name_prefix}-nlb"
  }
}

# Target Group - Dashboard (443)
resource "aws_lb_target_group" "dashboard" {
  name     = "${var.name_prefix}-dashboard-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "443"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.name_prefix}-dashboard-tg"
  }
}

# Target Group - Agent Events (1514)
resource "aws_lb_target_group" "agent_events" {
  name     = "${var.name_prefix}-events-tg"
  port     = 1514
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "1514"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.name_prefix}-events-tg"
  }
}

# Target Group - Agent Registration (1515)
resource "aws_lb_target_group" "agent_registration" {
  name     = "${var.name_prefix}-register-tg"
  port     = 1515
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "1515"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.name_prefix}-register-tg"
  }
}

# Listener - Dashboard (443)
resource "aws_lb_listener" "dashboard" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }
}

# Listener - Agent Events (1514)
resource "aws_lb_listener" "agent_events" {
  load_balancer_arn = aws_lb.main.arn
  port              = 1514
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent_events.arn
  }
}

# Listener - Agent Registration (1515)
resource "aws_lb_listener" "agent_registration" {
  load_balancer_arn = aws_lb.main.arn
  port              = 1515
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent_registration.arn
  }
}
