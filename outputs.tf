output "ecr_repository_url" {
  value = aws_ecr_repository.strapi_repo.repository_url
}

output "cluster_name" {
  value = aws_ecs_cluster.strapi_cluster.name
}