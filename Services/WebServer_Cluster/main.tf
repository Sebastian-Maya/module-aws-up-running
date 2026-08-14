/*
## Y después de buscar mucho, terminó siendo esto el problema:
## AWS ha deprecated los Launch Configuration
## AWS obliga a usar Launch Templates en su lugar.

#S3 como backend para guardar .tfstate
terraform {
  backend "s3" {
    bucket       = "terra-up-and-running"
    key          = "Stage/Services/WebServer_Cluster/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
*/

resource "aws_launch_template" "web-server-1" {
  name_prefix            = "web-server-"
  image_id               = "ami-0ea1cddefe0c4aed5"
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.instance.id]

  # Render the User Data script as a template
  user_data = base64encode( templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }))

  # Required when using a launch configuration with an auto-scaling group.
  lifecycle {
    create_before_destroy = true
  }
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


resource "aws_autoscaling_group" "asg-web-server-1" {
  #launch_configuration = aws_launch_configuration.web-server-1.name
  launch_template {
    id      = aws_launch_template.web-server-1.id
    version = "$Latest"
  }
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.asg-group.arn]
  health_check_type   = "ELB"

  min_size = var.min_num_size
  max_size = var.max_num_size

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-auto-scaling-group"
    propagate_at_launch = true
  }
}


resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb" "lb-servers" {
  name               = "${var.cluster_name}-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids

  security_groups = [aws_security_group.lb-nsg.id]
}


resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.lb-servers.arn
  port              = local.http_port
  protocol          = "HTTP"

  #By default, return a 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 ERROR: PAGE NOT FOUND"
      status_code  = 404
    }
  }
}


resource "aws_security_group" "lb-nsg" {
  name = "${var.cluster_name}-lb-nsg"
}


resource "aws_security_group_rule" "Allow_inbound_http" {
  type              = "ingress"
  security_group_id = aws_security_group.lb-nsg.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}


resource "aws_security_group_rule" "Allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.lb-nsg.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

/* Inline block changed to more flexible one - separate into resources
  #Allow inbound requests
  ingress { #Tenia ingress={} - Usar = es un error porque no es un argumento, es un bloque {}
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips       #["0.0.0.0/0"] I'm forgetting to put the value between quotes
  }

  #Allow all outbound requests
  egress {
    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_protocol
    cidr_blocks = local.all_ips
  }
}
*/

resource "aws_lb_target_group" "asg-group" {
  name     = "${var.cluster_name}-asg-group"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.lb-listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg-group.arn
  }
}


#get the web server to read those outputs from the database’s state file
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}