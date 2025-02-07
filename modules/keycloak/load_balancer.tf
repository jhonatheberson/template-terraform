resource "aws_lb" "keycloak" {
  name               = "keycloak-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.keycloak.id]
  subnets            = var.subnets

  depends_on = [
    aws_security_group.keycloak
  ]
}

resource "aws_lb_target_group" "keycloak" {
  name        = "keycloak-tg"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-302"
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }
}

# Declare the Route 53 zone data source
data "aws_route53_zone" "zone" {
  name = var.load_balancer_domain
}

resource "aws_route53_record" "keycloak_lb" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "keycloak.${var.load_balancer_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.keycloak.dns_name]
}


output "keycloak_url" {
  description = "A URL pública para acessar o Keycloak"
  value       = "https://${aws_route53_record.keycloak_lb.name}"
}