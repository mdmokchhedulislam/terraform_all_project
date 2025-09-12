terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

# ------------------------
# Variables (adjust in terraform.tfvars)
# ------------------------
variable "region"      { type = string  default = "ap-south-1" }
variable "env"         { type = string  default = "prod" }
variable "cluster"     { type = string  default = "industry" }
variable "vpc_id"      { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "ami_id"      { type = string }
variable "instance_type" { type = string default = "t3.micro" }
variable "key_name"    { type = string default = "" }
variable "admin_cidr"  { type = string default = "YOUR_IP/32" }
variable "asg_min"     { type = number default = 1 }
variable "asg_desired" { type = number default = 2 }
variable "asg_max"     { type = number default = 6 }

# ------------------------
# IAM role + instance profile for EC2
# ------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.cluster}-ec2-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = { Environment = var.env, Name = "${var.cluster}-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "cw" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
# optional: s3 read-only for artifacts
resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.cluster}-instance-profile-${var.env}"
  role = aws_iam_role.ec2_role.name
}

# ------------------------
# Security Groups
# ------------------------
resource "aws_security_group" "alb_sg" {
  name   = "${var.cluster}-alb-sg-${var.env}"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.cluster}-alb-sg-${var.env}", Environment = var.env }
}

resource "aws_security_group" "ec2_sg" {
  name   = "${var.cluster}-ec2-sg-${var.env}"
  vpc_id = var.vpc_id

  # allow from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow HTTP from ALB"
  }

  # optional SSH (lock down with admin_cidr)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "SSH for admins"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster}-ec2-sg-${var.env}", Environment = var.env }
}

# ------------------------
# Launch Template (ASG-friendly)
# ------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "${var.cluster}-lt-${var.env}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile { name = aws_iam_instance_profile.ec2_profile.name }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  # use base64 user_data; simple nginx bootstrap (works for ubuntu/amazon linux)
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    # update (try apt then yum)
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y nginx
      systemctl enable nginx
      systemctl start nginx
      echo "<h1>${var.cluster} - ${var.env} - $(hostname)</h1>" > /var/www/html/index.html
    else
      yum update -y
      yum install -y nginx
      systemctl enable nginx
      systemctl start nginx
      echo "<h1>${var.cluster} - ${var.env} - $(hostname)</h1>" > /usr/share/nginx/html/index.html
    fi
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster}-ec2-${var.env}"
      Environment = var.env
    }
  }
}

# ------------------------
# ALB + Target Group + Listener
# ------------------------
resource "aws_lb" "alb" {
  name               = "${var.cluster}-alb-${var.env}"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
  tags = { Name = "${var.cluster}-alb-${var.env}", Environment = var.env }
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.cluster}-tg-${var.env}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.cluster}-tg-${var.env}" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ------------------------
# Auto Scaling Group
# ------------------------
resource "aws_autoscaling_group" "asg" {
  name_prefix         = "${var.cluster}-asg-${var.env}-"
  min_size            = var.asg_min
  max_size            = var.asg_max
  desired_capacity    = var.asg_desired
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  # graceful rolling updates when replacing
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster}-asg-${var.env}"
    propagate_at_launch = true
  }
}

# ------------------------
# Target Tracking Scaling Policy (CPU average of ASG)
# ------------------------
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.cluster}-cpu-target-${var.env}"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value       = 50.0     # target average CPU% per ASG
    disable_scale_in   = false
    scale_out_cooldown = 120
    scale_in_cooldown  = 300
  }
}

# ------------------------
# Optional: Scheduled Scaling example (scale up for office hours)
# ------------------------
resource "aws_autoscaling_schedule" "weekday_peak" {
  scheduled_action_name  = "${var.cluster}-weekday-peak-${var.env}"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  recurrence             = "0 9 * * 1-5" # cron: at 09:00 UTC Mon-Fri (adjust for timezone)
  min_size               = var.asg_desired
  desired_capacity       = var.asg_desired
  max_size               = var.asg_max
}

# ------------------------
# Outputs
# ------------------------
output "alb_dns" { value = aws_lb.alb.dns_name }
output "asg_name" { value = aws_autoscaling_group.asg.name }
output "launch_template_id" { value = aws_launch_template.lt.id }
