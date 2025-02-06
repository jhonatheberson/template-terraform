variable "project_alias" {
  type = string
}

variable "project_code" {
  type = string
}

variable "project_cost_center" {
  type = string
}

variable "project_pep" {
  type = string
}

variable "dns_zone_name" {
  type        = string
  description = "The name of the DNS zone"
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = var.environment == "production" || var.environment == "staging" || var.environment == "sandbox"
    error_message = "Environment must be either production, staging, or sandbox"
  }
}

variable "tags_to_append" {
  type    = map(string)
  default = {}
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

variable "aws_profile" {
  type = string
}

variable "aws_account_id" {
  description = "ID da conta AWS"
  type        = string
}