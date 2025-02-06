data "aws_subnet" "private_app_subnets" {
  count = length(var.vpc_config_private_app_subnet_ids)
  id    = var.vpc_config_private_app_subnet_ids[count.index]
}
data "aws_subnet" "private_data_subnets" {
  count = length(var.vpc_config_private_data_subnet_ids)
  id    = var.vpc_config_private_data_subnet_ids[count.index]
}
data "aws_route53_zone" "dns" {
  name = var.dns_zone_name
}
