locals {
  tags                     = merge(var.tags_to_append, { Environment = var.environment, application_name = var.service_identifier })
  vpc_id                   = data.aws_subnet.public_subnets[0].vpc_id
  microservices_dns_suffix = "ms.${var.environment}.${var.dns_zone_name}"
  lb_entries               = { for lb_entry in var.service_lb_entries : lb_entry.port => lb_entry }
  secret_entries           = [for v in var.service_secrets : "\"${v}\""]
}

resource "aws_lb_target_group" "ecs_service_target_group" {
  for_each    = local.lb_entries
  name        = "${substr(var.service_identifier, 0, 8)}${each.value.port}-ecs-service-${substr(uuid(), 0, 3)}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    path                = each.value.health_check_path
    matcher             = each.value.health_check_matcher
    healthy_threshold   = 2
    interval            = 300
    unhealthy_threshold = 10
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }
  tags = local.tags
}

resource "aws_lb_listener_rule" "lb_listener" {
  for_each     = { for lb_target_group in aws_lb_target_group.ecs_service_target_group : lb_target_group.port => lb_target_group }
  listener_arn = var.alb_listener_arn

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }



  condition {
    path_pattern {
      values = [var.service_lb_entries[index(var.service_lb_entries.*.port, each.value.port)].path_pattern]
    }
  }

  dynamic "condition" {
    for_each = aws_lb_target_group.ecs_service_target_group
    content {
      dynamic "host_header" {
        for_each = var.service_lb_entries[index(var.service_lb_entries.*.port, condition.value.port)].host_prefix == null ? [] : [condition.value]
        content {
          values = ["${var.service_lb_entries[index(var.service_lb_entries.*.port, condition.value.port)].host_prefix}-${var.service_identifier}.${local.microservices_dns_suffix}"]
        }
      }
    }
  }

  tags = local.tags
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.service_identifier}_ecs_task_execution_role_${var.environment}"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF

  tags = local.tags
}

resource "aws_iam_role_policy" "password_policy_ssm" {
  count = length([for v in var.service_secrets : v]) > 0 ? 1 : 0
  name  = "password-policy-ssm-${var.service_identifier}-${var.environment}"
  role  = aws_iam_role.ecs_task_execution_role.id

  policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        ${join(",", local.secret_entries)}
      ]
    }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_service_log_group" {
  name = "ecs/${var.environment}/${var.service_identifier}-service-log-group"

  tags = local.tags
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = var.service_identifier
  network_mode             = "awsvpc"
  cpu                      = var.service_cpu_unit
  memory                   = var.service_memory_mb
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = var.service_container_name
      image     = "${var.service_container_image}:latest"
      cpu       = var.service_cpu_unit
      memory    = var.service_memory_mb
      essential = true
      environment = concat(
        [for k, v in var.service_environment : { name = k, value = v }],
        [] /* Any fixed environment */
      )
      secrets = concat(
        [for k, v in var.service_secrets : { name = k, valueFrom = v }],
        [] /* Any fixed secret */
      )
      portMappings = [for lb_entry in var.service_lb_entries :
        {
          containerPort = lb_entry.port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_service_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = var.service_container_name
        }
      }
    }
  ])

  tags = local.tags
}

output "name_aws_ecs_task_definition" {
  value = aws_ecs_task_definition.ecs_task_definition.arn
}

resource "aws_security_group" "allow_service_access" {
  name        = "allow_${var.service_identifier}_service_access_${var.environment}_${substr(uuid(), 0, 3)}_sg"
  description = "Allow ${var.service_identifier} alb inbound traffic"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = toset(var.service_lb_entries.*.port)
    content {
      description = "Allow inbound from alb to ${var.service_identifier}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      # cidr_blocks = [for s in data.aws_subnet.public_subnets : s.cidr_block]
      cidr_blocks = ["0.0.0.0/0"]  # Permitir de todos os IPs
      ipv6_cidr_blocks = ["::/0"]
    }
  }

   # Adicionar as portas 8443 e 8080 manualmente
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [ name ]
  }

  tags = merge(local.tags, { Name = "allow_${var.service_identifier}_service_access_${var.environment}" })
}

resource "aws_ecs_service" "ecs_service" {
  name                              = "${var.service_identifier}_ecs_service_${var.environment}"
  cluster                           = var.ecs_cluster_id
  launch_type                       = "FARGATE"
  task_definition                   = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count                     = 1
  health_check_grace_period_seconds = 300
  timeouts {
    delete = "40m"  # Aumente o tempo de espera para 40 minutos
  }

   deployment_controller {
    type = "ECS"
  }


  dynamic "load_balancer" {
    for_each = { for lb_target_group in aws_lb_target_group.ecs_service_target_group : lb_target_group.port => lb_target_group }
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = var.service_container_name
      container_port   = var.service_lb_entries[index(var.service_lb_entries.*.port, load_balancer.value.port)].port
    }
  }

  network_configuration {
    subnets = var.vpc_config_private_app_subnet_ids
    assign_public_ip = true  # IP público para a tarefa
    security_groups = [
      aws_security_group.allow_service_access.id
    ]
  }

  depends_on = [
    aws_lb_target_group.ecs_service_target_group,
    aws_ecs_task_definition.ecs_task_definition,
    aws_lb_listener_rule.lb_listener,
    aws_security_group.allow_service_access
  ]

  tags = local.tags
}

output "name_aws_ecs_service" {
  value = aws_ecs_service.ecs_service.name
}

output "microservice_url" {
  value = [for lb_entry in var.service_lb_entries : {
    port = lb_entry.port
    url  = lb_entry.host_prefix == null ? "" : "https://${lb_entry.host_prefix}-${var.service_identifier}.${local.microservices_dns_suffix}"
  }]
}
