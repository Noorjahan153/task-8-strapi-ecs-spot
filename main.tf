provider "aws" {
  region = "us-east-1"
}

############################
# Default VPC
############################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################
# Security Group for ALB
############################

resource "aws_security_group" "noor_alb_sg" {
  name   = "noor-alb-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
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
}

############################
# Security Group for ECS
############################

resource "aws_security_group" "noor_ecs_sg" {
  name   = "noor-ecs-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 1337
    to_port         = 1337
    protocol        = "tcp"
    security_groups = [aws_security_group.noor_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# ECR
############################

resource "aws_ecr_repository" "noor_repo" {
  name = "noor-strapi-repo"
}

############################
# ECS Cluster
############################

resource "aws_ecs_cluster" "noor_cluster" {
  name = "noor-strapi-cluster"
}

############################
# IAM Role
############################

resource "aws_iam_role" "noor_task_execution_role" {
  name = "noor-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "noor_execution_policy" {
  role       = aws_iam_role.noor_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################
# Task Definition
############################

resource "aws_ecs_task_definition" "noor_task" {
  family                   = "noor-strapi-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.noor_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "noor-strapi"
      image     = "${aws_ecr_repository.noor_repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 1337
          hostPort      = 1337
        }
      ]
    }
  ])
}

############################
# ALB
############################

resource "aws_lb" "noor_alb" {
  name               = "noor-strapi-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.noor_alb_sg.id]
}

resource "aws_lb_target_group" "noor_tg" {
  name        = "noor-strapi-tg"
  port        = 1337
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_lb_listener" "noor_listener" {
  load_balancer_arn = aws_lb.noor_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.noor_tg.arn
  }
}

############################
# ECS Service (FARGATE_SPOT)
############################

resource "aws_ecs_service" "noor_service" {
  name            = "noor-strapi-service"
  cluster         = aws_ecs_cluster.noor_cluster.id
  task_definition = aws_ecs_task_definition.noor_task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.noor_ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.noor_tg.arn
    container_name   = "noor-strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.noor_listener]
}

############################
# OUTPUT
############################

output "noor_alb_dns" {
  value = aws_lb.noor_alb.dns_name
}