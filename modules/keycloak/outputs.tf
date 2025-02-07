output "load_balancer_url" {
  value = aws_lb.keycloak.dns_name
}

output "keycloak_security_group_id" {
  description = "ID do Security Group do Keycloak"
  value       = aws_security_group.keycloak.id
}

output "aws_ecs_task_definition_name" {
  description = "name do aws_ecs_task_definition do Keycloak"
  value       = aws_ecs_task_definition.keycloak.execution_role_arn
}


output "aws_ecs_service_name" {
  description = "name do aws_ecs_service do Keycloak"
  value       = aws_ecs_service.keycloak.name
}

output "aws_ecs_cluster_name" {
  description = "name do aws_ecs_cluster do Keycloak"
  value       = aws_ecs_cluster.keycloak.name
}

output "aws_ecr_repository_name" {
  description = "name do aws_ecr_repository do Keycloak"
  value       = aws_ecr_repository.keycloak.name
}
