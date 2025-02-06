locals {
  tags              = merge(var.tags_to_append, { Environment = var.environment })
  vpc_id            = data.aws_subnet.public_subnets[0].vpc_id
  microservices_dns = "ms.${var.environment}.${data.aws_route53_zone.zone.name}"
}

resource "aws_ecr_repository" "container_registry" {
  name                 = "ecr_${var.environment}/auth"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

output "container_registry_url" {
  value = aws_ecr_repository.container_registry.repository_url
}
