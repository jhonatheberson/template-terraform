resource "aws_kms_key" "sqs_key" {
  description             = "KMS key for SQS encryption"
  deletion_window_in_days = 30
  tags                    = merge(local.tags, { Name = "sqs_key_${var.environment}" })
}

resource "aws_sqs_queue" "sqs" {
  name                              = "sqs_ingestion_${var.environment}"
  delay_seconds                     = var.sqs_delayseconds
  max_message_size                  = var.max_message_size
  message_retention_seconds         = var.message_retention_seconds
  visibility_timeout_seconds        = var.visibility_timeout_seconds
  receive_wait_time_seconds         = var.receive_wait_time_seconds
  
  kms_master_key_id                 = aws_kms_key.sqs_key.key_id
  kms_data_key_reuse_period_seconds = 300

  tags                              = local.tags
}
