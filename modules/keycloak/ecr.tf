resource "aws_ecr_repository" "keycloak" {
  name                 = var.ecr_repo_name
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }

  depends_on = [
    aws_security_group.keycloak,
    aws_lb.keycloak,
    aws_lb_target_group.keycloak,
  ]
}
