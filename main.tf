provider "aws" {
  region = var.region
}

############################
# DEFAULT VPC
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
# SECURITY GROUP
############################

resource "aws_security_group" "noor_sg" {
  name        = "noor-strapi-sg"
  description = "Allow Strapi traffic"
  vpc_id      = data.aws_vpc.default.id

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
# ECR REPOSITORY
############################

resource "aws_ecr_repository" "noor_repo" {
  name = "noor-strapi-repo"
}

############################
# ECS CLUSTER
############################

resource "aws_ecs_cluster" "noor_cluster" {
  name = "noor-strapi-cluster"
}

############################
# IAM ROLE
############################

resource "aws_iam_role" "noor_execution_role" {
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
  role       = aws_iam_role.noor_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################
# TASK DEFINITION
############################

resource "aws_ecs_task_definition" "noor_task" {
  family                   = "noor-strapi-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.noor_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "noor-strapi"
      image     = "${aws_ecr_repository.noor_repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 1337
          hostPort      = 1337
          protocol      = "tcp"
        }
      ]
    }
  ])
}

############################
# ECS SERVICE (FARGATE SPOT)
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
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.noor_sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.noor_execution_policy
  ]
}