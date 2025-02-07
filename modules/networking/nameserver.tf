# resource "aws_route53_zone" "zone" {
#   name = var.dns_zone_name
# }



output "nameserver" {
  value = data.aws_route53_zone.zone.name_servers
}

resource "aws_acm_certificate" "cert" {
  domain_name = var.dns_zone_name
  subject_alternative_names = [
    "*.${var.dns_zone_name}",
    "*.sandbox.${var.dns_zone_name}",
    "*.ms.sandbox.${var.dns_zone_name}",
    "static-content.sandbox.${var.dns_zone_name}"
  ]
  validation_method = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

output "acm_certificate_arn" {
  description = "ARN do certificado ACM para o domínio configurado"
  value       = aws_acm_certificate.cert.arn
}

resource "aws_route53_record" "route53_acm_certification_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = data.aws_route53_zone.zone.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "acm_certification_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_acm_certification_validation : record.fqdn]
}
