#################################
# PROVIDER
#################################

provider "aws" {
  region = "us-east-1"
}

#################################
# SECURITY GROUP
#################################

resource "aws_security_group" "sg" {
  name   = "noor-strapi-final-sg-dev"

  # Default VPC will be automatically used by AWS service
  vpc_id = "vpc-xxxxxxxx"   # ⭐ Put your default VPC ID from AWS Console

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

#################################
# ECR REPOSITORY
#################################

resource "aws_ecr_repository" "repo" {
  name = "noor-strapi-final-repo-dev"

  force_delete = true
}

#################################
# ECS CLUSTER
#################################

resource "aws_ecs_cluster" "cluster" {
  name = "noor-strapi-final-cluster-dev"
}

#################################
# TASK DEFINITION
#################################

resource "aws_ecs_task_definition" "task" {

  family                   = "noor-strapi-task-dev"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = "arn:aws:iam::811738710312:role/ecs_fargate_taskRole"
  task_role_arn      = "arn:aws:iam::811738710312:role/ecs_fargate_taskRole"

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = "${aws_ecr_repository.repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 1337
          protocol      = "tcp"
        }
      ]
    }
  ])
}

#################################
# ECS SERVICE
#################################

resource "aws_ecs_service" "service" {

  name            = "noor-strapi-service-dev"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {

    subnets = [
      "subnet-xxxxxx",   # ⭐ Put 2 default public subnet IDs
      "subnet-yyyyyy"
    ]

    security_groups = [
      aws_security_group.sg.id
    ]

    assign_public_ip = true
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200
}
