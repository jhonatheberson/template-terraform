resource "aws_ecs_cluster" "keycloak" {
  name = var.ecs_cluster_name

  depends_on = [
    aws_security_group.keycloak,
    aws_lb.keycloak,
    aws_lb_target_group.keycloak,
  ]
}
