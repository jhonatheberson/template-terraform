locals {
  tags            = merge(var.tags_to_append, { Environment = var.environment })
  api_domain_name = "api.${var.environment}.${data.aws_route53_zone.dns.name}"
  api_v2_domain_name = "api-v2.${var.environment}.${data.aws_route53_zone.dns.name}"
}
