output "load_balancer_url" {
  value = aws_lb.keycloak.dns_name
}
