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

variable "vpc_config_private_app_subnet_ids" {
  type    = list(string)
  default = []
}

variable "vpc_config_private_data_subnet_ids" {
  type    = list(string)
  default = []
}

variable "tags_to_append" {
  type    = map(string)
  default = {}
}

variable "dns_zone_name" {
  type = string
}

variable "initial_db_name" {
  type = string
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type = string
}

