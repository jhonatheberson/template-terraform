variable "ecr_repo_name" {}
variable "ecs_cluster_name" {}
variable "desired_task_count" { default = 1 }
variable "container_port" { default = 8080 }
variable "load_balancer_domain" {}
variable "certificate_arn" {}
variable "vpc_id" {}
variable "subnets" { type = list(string) }
variable "db_host" {
  description = "O endpoint do banco de dados PostgreSQL"
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
}

variable "db_username" {
  description = "Nome de usuário para o banco de dados PostgreSQL"
  type        = string
}

variable "db_password" {
  description = "Senha do usuário para o banco de dados PostgreSQL"
  type        = string
  sensitive   = true
}

variable "security_group" {
  description = "O security_group do banco de dados PostgreSQL"
  type        = string
}

variable "container_ports" {
  type    = list(number)
  default = [8080, 8443]
}


variable "aws_account_id" {
  description = "ID da conta AWS"
  type        = string
}