output "load_balancer_url" {
  value = aws_lb.keycloak.dns_name
}

output "keycloak_security_group_id" {
  description = "ID do Security Group do Keycloak"
  value       = aws_security_group.keycloak.id
}
