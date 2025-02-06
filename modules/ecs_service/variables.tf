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

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "dns_zone_name" {
  type        = string
  description = "The name of the DNS zone"
}

variable "alb_listener_arn" {
  type        = string
  description = "The ARN of the ALB listener"
}

variable "ecs_cluster_id" {
  type        = string
  description = "The ID of the ECS cluster"
}

variable "vpc_config_private_app_subnet_ids" {
  type        = list(string)
  description = "The list of private app subnet ids"
}


variable "vpc_config_public_subnet_ids" {
  type    = list(string)
  default = []
}

variable "service_identifier" {
  type        = string
  description = "The identifier of service"
}
variable "service_lb_entries" {
  type = list(object({
    port                 = number
    host_prefix          = string
    path_pattern         = string
    health_check_matcher = string
    health_check_path    = string
  }))
}

variable "service_environment" {
  type    = map(string)
  default = {}
}

variable "service_secrets" {
  type    = map(string)
  default = {}
}

variable "service_cpu_unit" {
  type        = number
  description = "CPU unit of service (256, 512, 1024 ...)"
  default     = 256
}

variable "service_memory_mb" {
  type        = number
  description = "Memory mb of service (1024, 2048, 4096 ...)"
  default     = 2048
}

variable "service_container_name" {
  type        = string
  description = "Name of container to receive traffic from servicer"
}

variable "service_container_image" {
  type        = string
  description = "Image address of container to receive traffic from servicer"
}
