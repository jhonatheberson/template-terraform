output "test_v2_cURL" {
  #   value = "curl -X POST -H 'Content-Type: application/json' -d '{\"id\":\"test\", \"docs\":[{\"key\":\"value\"}]}' https://${local.api_domain_name}/"
  value = "curl -X POST -H 'Content-Type: application/json' -d '{\"id\":\"test\", \"docs\":[{\"key\":\"value\"}]}' https://${local.api_v2_domain_name}/"
}

resource "aws_apigatewayv2_api" "api" {
  name          = "ingestion_api_${var.environment}_v2"
  protocol_type = "HTTP"

  tags = local.tags
}

resource "aws_route53_record" "api-v2" {
  name    = aws_apigatewayv2_domain_name.api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.dns.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
  }
}

resource "aws_apigatewayv2_route" "api" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.api-sqs.id}"
}

resource "aws_apigatewayv2_integration" "api-sqs" {
  api_id              = aws_apigatewayv2_api.api.id
  credentials_arn     = aws_iam_role.api.arn
  description         = "SQS SendMessage"
  integration_type    = "AWS_PROXY"
  integration_subtype = "SQS-SendMessage"

  request_parameters = {
    QueueUrl    = aws_sqs_queue.sqs.id
    MessageBody = "$request.body"
  }

#   Disclaimer: The below block is commented out because AWS Api Gateway v2 does not support response body overwrite

#   response_parameters {
#     status_code = "200"
#     mappings = {
#       "overwrite:header.Content-Type" = "'application/json'"
#     }
#   }

}

resource "aws_apigatewayv2_deployment" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  description = "Deployment"
}

resource "aws_cloudwatch_log_group" "api" {
  name = "/aws/apigateway/ingestion_api_${var.environment}_v2"
  tags = local.tags
}

resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "main"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format           = jsonencode({
      requestId = "$context.requestId",
      ip        = "$context.identity.sourceIp",
      user      = "$context.identity.user",
      request   = "$context.requestTime",
      status    = "$context.status",
      response  = "$context.responseLength"
    })
  
  }
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = local.api_v2_domain_name
  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.cert.arn
    security_policy = "TLS_1_2"
    endpoint_type   = "REGIONAL"
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  domain_name = aws_apigatewayv2_domain_name.api.domain_name
  stage       = aws_apigatewayv2_stage.api.name
  api_id      = aws_apigatewayv2_api.api.id
}
