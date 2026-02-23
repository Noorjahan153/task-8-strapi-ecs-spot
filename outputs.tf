output "noor_ecr_repository_url" {
  value = aws_ecr_repository.noor_repo.repository_url
}

output "noor_cluster_name" {
  value = aws_ecs_cluster.noor_cluster.name
}

output "noor_alb_dns" {
  value = aws_lb.noor_alb.dns_name
}