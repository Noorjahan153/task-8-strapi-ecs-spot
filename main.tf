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
# Security Group
############################

resource "aws_security_group" "strapi_sg" {
  name   = "strapi-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 1337
    to_port     = 1337
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
# ECR Repository
############################

resource "aws_ecr_repository" "strapi_repo" {
  name = "strapi-repo"
}

############################
# ECS Cluster
############################

resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-cluster"
}

############################
# IAM Role
############################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-strapi"

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

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################
# Task Definition
############################

resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = "${aws_ecr_repository.strapi_repo.repository_url}:latest"
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
# ECS Service (FARGATE SPOT)
############################

resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi_task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.strapi_sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_policy
  ]
}