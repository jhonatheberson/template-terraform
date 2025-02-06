resource "aws_ecs_cluster" "keycloak" {
  name = var.ecs_cluster_name
}
