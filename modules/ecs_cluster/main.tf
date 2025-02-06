locals {
  tags              = merge(var.tags_to_append, { Environment = var.environment })
  vpc_id            = data.aws_subnet.public_subnets[0].vpc_id
  microservices_dns = "ms.${var.environment}.${data.aws_route53_zone.zone.name}"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs_cluster_${var.environment}"
  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "capacity_provider" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls_${var.environment}"
  description = "Allow TLS inbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    description      = "Allow TLS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

resource "random_string" "random_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
  keepers = local.tags
}

resource "aws_s3_bucket" "load-balancer-logs-bucket" {
  bucket = "load-balancer-logs-${var.environment}-${random_string.random_bucket_suffix.result}"
  tags   = local.tags
  force_destroy = true # Esvazia o bucket automaticamente antes de excluí-lo

}

resource "aws_s3_bucket_public_access_block" "load-balancer-logs-public-access-block" {
  bucket = aws_s3_bucket.load-balancer-logs-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "load-balancer-logs" {
  bucket = aws_s3_bucket.load-balancer-logs-bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "b_acl" {
  bucket     = aws_s3_bucket.load-balancer-logs-bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.load-balancer-logs]
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.load-balancer-logs-bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_lb_write.json
}

resource "aws_lb" "loadbalancer" {
  name               = "loadbalancer-${var.environment}"
  load_balancer_type = "application"

  subnets = var.vpc_config_public_subnet_ids

  security_groups = [
    aws_security_group.allow_tls.id
  ]

  # Fix: Disabling logging is security-sensitive terraform:S6258
  access_logs {
    enabled = true
    bucket = aws_s3_bucket.load-balancer-logs-bucket.bucket
  }


  enable_http2 = true

  tags = local.tags

  depends_on = [aws_security_group.allow_tls]
}

resource "aws_lb_listener" "loadbalancer_listener" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.tags, { Name = "loadbalancer-listener-${var.environment}" })
}

resource "aws_lb_listener" "loadbalancer_listener_secure" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      status_code  = "404"
      message_body = "{\"message: \"Not Found\"\"}"
    }
  }

  tags = merge(local.tags, { Name = "loadbalancer-listener-${var.environment}" })
}

resource "aws_route53_record" "cdn_domain_name" {
  name    = "*.${local.microservices_dns}"
  type    = "CNAME"
  zone_id = data.aws_route53_zone.zone.zone_id
  ttl     = 60

  records = [aws_lb.loadbalancer.dns_name]
}

output "alb_listener_arn" {
  value = aws_lb_listener.loadbalancer_listener_secure.arn
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.ecs_cluster.id
}
