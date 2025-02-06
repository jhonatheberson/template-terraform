data "aws_route53_zone" "dns" {
  name = var.dns_zone_name
}

data "aws_acm_certificate" "cert" {
  domain = var.dns_zone_name
}
