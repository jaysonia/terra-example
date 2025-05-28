
provider "aws" {
  region = "us-west-1"
}

# Create VPC Network with private and public subnets
# Using the terraform aws module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = "web-app-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}


resource "aws_ecs_cluster" "main" {
    name = "web-app-cluster"

    setting {
        name = "containerInsights"
        value = "enabled"
    }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
    name = "web-app-ecr"
    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
      scan_on_push = false
    }

    tags = {
        Environment = var.environment
        Project = var.project_name
    }
}

resource "aws_iam_role" "ecs_task_execution" {
    name    = "web-app-ecs-execution-role"

    assume_role_policy = jsonencode({
        version = "2012-10-17"
        statement   = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal   = {
                Service = "ecs-tasks.amazonaws.com"
            }
        }]
    })

    tags = {
        Environment = "Eng"
        Project     = var.project_name
    }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
    role       = aws_iam_role.ecs_task_execution.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
    name = "${var.project_name}-ecs-task-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "ecs-tasks.amazonaws.com"
            }
        },
        ]
    })

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}

resource "aws_iam_role_policy" "ecs_task_cloudwatch_policy" {
    name = "web-app-ecs-task-cloudwatch-policy"
    role = aws_iam_role.ecs_task_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:CreateLogGroup"
            ]
            Resource = "*"
        },
        ]
    })
}

resource "aws_cloudwatch_log_group" "app" {
    name              = "/ecs/web-app"
    retention_in_days = 7

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}

resource "aws_ecs_task_definition" "app" {
    family                   = "${var.project_name}-app-task"
    cpu                      = var.fargate_cpu
    memory                   = var.fargate_memory
    network_mode             = "awsvpc" # Required for Fargate
    requires_compatibilities = ["FARGATE"]
    execution_role_arn       = aws_iam_role.ecs_task_execution.arn
    task_role_arn            = aws_iam_role.ecs_task_role.arn

    container_definitions = templatefile("${path.module}/container_definition.json.tpl", {
        app_name            = var.project_name
        app_image           = "${aws_ecr_repository.app.repository_url}:latest"
        fargate_cpu         = var.fargate_cpu
        fargate_memory      = var.fargate_memory
        container_port      = var.app_container_port
        log_group_name      = aws_cloudwatch_log_group.app.name
        aws_region          = var.aws_region
        environment_variables = jsonencode(var.app_environment_variables)
    })

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}

# Application load balancer
resource "aws_lb" "app" {
    name = "${var.project_name}-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb.id]
    subnets         = module.vpc.public_subnets

    enable_deletion_protection = false

    tags = {
        Environment = var.environment
    }
}

resource "aws_lb_target_group" "app" {
    name = "${var.project_name}-tg"
    port = var.app_container_port
    protocol = "HTTP"
    vpc_id = module.vpc.vpc_id  
    target_type = "ip"

    health_check {
      path = var.app_health_check_path
      protocol = "HTTP"
      matcher = "200"
      interval = 30
      timeout = 5
      healthy_threshold = 2
      unhealthy_threshold = 5
    }

    tags = {
        Environment = var.environment
    }
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.app.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "redirect"
        redirect {
            port = 443
            protocol = "HTTPS"
            status_code = "HTTP_301"
            host = "#{host}"
            path = "/#{path}"
            query = "#{query}"
        }
    }

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}

resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.app.arn
    port  = 443
    protocol = "HTTPS"
    ssl_policy = "ELBSecurityPolicy-2016-08"
    certificate_arn = var.ssl_certificate

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.app.arn
    }

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}

# security groups
resource "aws_security_group" "alb" {
    name        = "${var.project_name}-alb-sg"
    description = "Allow HTTP/HTTPS traffic to ALB"
    vpc_id      = module.vpc.vpc_id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}

# security group for ecs tasks
resource "aws_security_group" "ecs_tasks" {
    name        = "${var.project_name}-ecs-tasks-sg"
    description = "Allow inbound traffic from ALB to ECS Fargate tasks and outbound to internet"
    vpc_id      = module.vpc.vpc_id

    ingress {
        from_port       = var.app_container_port
        to_port         = var.app_container_port
        protocol        = "tcp"
        security_groups = [aws_security_group.alb.id]
        description     = "Allow traffic from ALB"
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}


resource "aws_ecs_service" "app" {
    name            = "${var.project_name}-service"
    cluster         = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.app.arn
    desired_count   = var.app_desired_count 
    launch_type     = "FARGATE"

    network_configuration {
        subnets          = module.vpc.private_subnets
        security_groups  = [aws_security_group.ecs_tasks.id]
        assign_public_ip = false 
    }

    # Load balancer integration
    load_balancer {
        target_group_arn = aws_lb_target_group.app.arn
        container_name   = var.project_name 
        container_port   = var.app_container_port
    }

    deployment_controller {
        type = "ECS"
    }
    deployment_circuit_breaker {
        enable   = true
        rollback = true
    }

    deployment_maximum_percent         = 200
    deployment_minimum_healthy_percent = 100

    depends_on = [
        aws_lb_listener.http,
        aws_lb_target_group.app,
        aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    ]

    tags = {
        Environment = var.environment
        Project     = var.project_name
    }
}