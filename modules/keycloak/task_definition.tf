resource "aws_ecs_task_definition" "keycloak" {
  family                   = "keycloak-task"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "keycloak"
    image     = "${aws_ecr_repository.keycloak.repository_url}:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [
      {
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }
    ]
    environment = [
      { name = "KC_DB", value = "postgres" },
      { name = "KC_DB_URL", value = var.db_host },
      { name = "KC_DB_USERNAME", value = var.db_username },
      { name = "KC_DB_PASSWORD", value = var.db_password },
      { name = "KEYCLOAK_ADMIN", value = "admin" },
      { name = "KEYCLOAK_ADMIN_PASSWORD", value = "admin" },
      { name = "KC_LOG_LEVEL", value = "DEBUG" },

      { name = "KC_HOSTNAME", value = "keycloak.${var.load_balancer_domain}" },  # Coloque o domínio público aqui
      { name = "KC_HOSTNAME_STRICT", value = "false" },  # A URL pública acessível via LB
      { name = "KC_IMPORT", value = "/opt/keycloak/data/import" },  # A URL pública acessível via LB

      # Caso esteja usando um proxy reverso (Load Balancer):
      { name = "KC_PROXY", value = "edge" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/keycloak"
        awslogs-region        = "us-east-1"  # Substitua pela sua região
        awslogs-stream-prefix = "keycloak"
      }
    }

  }])
}
