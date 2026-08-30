locals {
  common_tags = merge(var.tags, {
    Module = "alb"
  })
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "Internet-facing load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name_prefix}-app"
  port     = var.target_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # ECS tasks on EC2 register by instance id + host port.
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
