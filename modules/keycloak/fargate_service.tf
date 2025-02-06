resource "aws_ecs_service" "keycloak" {
  name            = "keycloak-service"
  cluster         = aws_ecs_cluster.keycloak.id
  task_definition = aws_ecs_task_definition.keycloak.arn
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.keycloak.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak.arn
    container_name   = "keycloak"
    container_port   = var.container_port
  }

  depends_on = [
    aws_security_group.keycloak,
    aws_lb.keycloak,
    aws_lb_target_group.keycloak,
  ]
}
