data "aws_subnet" "public_subnets" {
  count = length(var.vpc_config_public_subnet_ids)
  id    = var.vpc_config_public_subnet_ids[count.index]
}
data "aws_route53_zone" "zone" {
  name = var.dns_zone_name
}

data "aws_acm_certificate" "cert" {
  domain = var.dns_zone_name
}

data "aws_elb_service_account" "main" {}
