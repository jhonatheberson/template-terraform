resource "aws_cloudwatch_log_group" "ecs_keycloak" {
  name = "/ecs/keycloak"
  retention_in_days = 7
}


resource "aws_iam_policy" "ecs_cloudwatch_logs" {
  name        = "ECSCloudWatchLogsPolicy"
  description = "Permite ao ECS registrar logs no CloudWatch"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:us-east-1:${var.aws_account_id}:log-group:/ecs/keycloak:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_logs_attach" {
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
  role       = data.aws_iam_role.ecs_task_execution.name
}
