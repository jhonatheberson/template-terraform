variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "sandbox"
  validation {
    condition     = var.environment == "production" || var.environment == "staging" || var.environment == "sandbox"
    error_message = "Environment must be either production, staging, or sandbox"
  }
}

variable "tags_to_append" {
  type    = map(string)
  default = {}
}

variable "dns_zone_name" {
  type = string
}

##########SQS Queue Variables#############
variable "sqs_delayseconds" {
  type    = number
  default = 5
}
variable "max_message_size" {
  type    = number
  default = 262144
}
variable "message_retention_seconds" {
  type    = number
  default = 345600
}
variable "visibility_timeout_seconds" {
  type    = number
  default = 200
}
variable "receive_wait_time_seconds" {
  type    = number
  default = 10
}

######Lambda Variables###########
variable "lambda_vpc_config_subnet_ids" {
  type    = list(string)
  default = []
}

variable "lambda_vpc_config_security_group_ids" {
  type    = list(string)
  default = []
}

variable "lambda_description" {
  type    = string
  default = "Lambda function which calls code from S3 and invokes when S3 queue recieves a message"
}
variable "lambda_memory_size" {
  type    = number
  default = 128
}
variable "lambda_timeout" {
  type    = number
  default = 60
}
