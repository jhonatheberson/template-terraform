resource "aws_ecr_repository" "container_registry" {
  name                 = "ecr_${var.environment}/ingestion"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

output "container_registry_url" {
  value = aws_ecr_repository.container_registry.repository_url
}

data "aws_ecr_authorization_token" "token" {}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  registry_auth {
    address  = data.aws_ecr_authorization_token.token.proxy_endpoint
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

data "docker_registry_image" "lambda_base_image" {
  name = "hello-world" #"public.ecr.aws/lambda/dotnet:7"
}

resource "docker_image" "lambda_base_image" {
  name = data.docker_registry_image.lambda_base_image.name
}

resource "docker_tag" "lambda_base_image_ecr_tag" {
  target_image = "${aws_ecr_repository.container_registry.repository_url}:base"
  source_image = data.docker_registry_image.lambda_base_image.name
}

resource "docker_registry_image" "lambda_base_image_ecr" {
  name = "${aws_ecr_repository.container_registry.repository_url}:base"
}

#Lambda Function Resource
resource "aws_lambda_function" "lambda" {
  function_name = "lambda_ingestion_${var.environment}"
  role          = aws_iam_role.iam_lambda.arn
  description   = "Lambda function which calls code from ECR Image and invokes when SQS queue recieves a message"
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  depends_on    = [aws_iam_role.iam_lambda]

  image_uri    = docker_registry_image.lambda_base_image_ecr.name
  package_type = "Image"

  vpc_config {
    subnet_ids         = var.lambda_vpc_config_subnet_ids
    security_group_ids = var.lambda_vpc_config_security_group_ids
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [image_uri]
  }
}

output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}

#Lambda SQS Trigger
resource "aws_lambda_event_source_mapping" "lambda_test_sqs_trigger" {
  event_source_arn = aws_sqs_queue.sqs.arn
  function_name    = aws_lambda_function.lambda.arn
  depends_on       = [aws_sqs_queue.sqs]
}
