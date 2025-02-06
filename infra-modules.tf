locals {
  tags_to_append = {
    "Environment"             = var.environment
    "project_alias"       = var.project_alias
    "project_code"        = var.project_code
    "project_cost_center" = var.project_cost_center
    "project_pep"         = var.project_pep
  }
}

module "networking" {
  source         = "./modules/networking"
  environment    = var.environment
  tags_to_append = local.tags_to_append
  region         = var.region
  dns_zone_name  = var.dns_zone_name
}

output "nameserver_data" {
  value = {
    name = var.dns_zone_name
    NS   = module.networking.nameserver
  }
}

data "aws_security_group" "default" {
  vpc_id = module.networking.vpc_id
  name   = "default"
}

# module "ingestion" {
#   source         = "./modules/ingestion-http"
#   environment    = var.environment
#   tags_to_append = local.tags_to_append
#   region         = var.region

#   lambda_vpc_config_subnet_ids         = module.networking.private_app_subnet_ids
#   lambda_vpc_config_security_group_ids = [data.aws_security_group.default.id]
#   dns_zone_name                        = var.dns_zone_name

# }

# output "ingestion_data" {
#   value = {
#     ecr_repository_uri = module.ingestion.container_registry_url
#     lambda_arn         = module.ingestion.lambda_arn
#     ingestion_test_v2  = module.ingestion.test_v2_cURL
#   }
# }

module "database" {
  source         = "./modules/database"
  environment    = var.environment
  tags_to_append = local.tags_to_append
  region         = var.region

  vpc_config_private_app_subnet_ids  = module.networking.public_subnet_ids
  vpc_config_private_data_subnet_ids = module.networking.public_subnet_ids
  dns_zone_name                      = var.dns_zone_name

  initial_db_name = var.initial_db_name
  master_username = var.master_username
  master_password = var.master_password

  depends_on = [module.networking]
}

output "database_endpoint" {
  value = module.database.aws_rds_instance_postgresql_endpoint
}

output "database_security_group" {
  value = module.database.aws_security_group_postgres
}



# module "frontend" {
#   source         = "./modules/frontend"
#   environment    = var.environment
#   tags_to_append = local.tags_to_append
#   dns_zone_name  = var.dns_zone_name

#   depends_on = [module.networking]
# }

# output "frontend_data" {
#   value = {
#     frontend_url        = module.frontend.frontend_url
#     cdn_distribution_id = module.frontend.cdn_distribution_id
#     bucket_name         = module.frontend.bucket_name
#   }
# }

module "keycloak_deploy" {
  source               = "./modules/keycloak"
  ecr_repo_name        = "keycloak"
  ecs_cluster_name     = "keycloak-cluster"
  desired_task_count   = 1
  container_port       = 8080
  load_balancer_domain = var.dns_zone_name
  certificate_arn      = module.networking.acm_certificate_arn
  vpc_id               = module.networking.vpc_id
  subnets              = module.networking.public_subnet_ids

  # Passar as variáveis de banco de dados
  security_group       = module.database.aws_security_group_postgres
  db_host              = "jdbc:postgresql://${module.database.aws_rds_instance_postgresql_endpoint}:5432/${var.initial_db_name}"
  db_name              = var.initial_db_name
  db_username          = var.master_username
  db_password          = var.master_password
  aws_account_id       = var.aws_account_id

  depends_on = [module.networking, module.database]
}

output "keycloak_service_url" {
  value = module.keycloak_deploy.keycloak_url  # URL do serviço Keycloak
}


# module "ecs_cluster" {
#   source         = "./modules/ecs_cluster"
#   environment    = var.environment
#   tags_to_append = local.tags_to_append

#   vpc_config_public_subnet_ids = module.networking.public_subnet_ids
#   dns_zone_name                = var.dns_zone_name

#   depends_on = [module.networking]
# }


# module "ecr_repository" {
#   source         = "./modules/ecr_repository"
#   environment    = var.environment
#   tags_to_append = local.tags_to_append

#   vpc_config_public_subnet_ids = module.networking.public_subnet_ids
#   dns_zone_name                = var.dns_zone_name

#   depends_on = [module.networking]

# }

# output "ecr_repository_data" {
#   value = module.ecr_repository.container_registry_url
# }

# module "keycloak_ecs_service" {
#   source                  = "./modules/ecs_service"
#   environment             = var.environment
#   tags_to_append          = local.tags_to_append
#   service_identifier      = "keycloak-example"  # Nome do serviço Keycloak
#   service_container_name  = "keycloak"
#   service_container_image = module.ecr_repository.container_registry_url  # Imagem do Keycloak (ajuste conforme necessário)

#   service_lb_entries = [
#     {
#       port                 = 8080  # Porta padrão do Keycloak
#       host_prefix          = "keycloak"
#       path_pattern         = "/*"
#       health_check_matcher = "200"
#       health_check_path    = "/auth/realms/master/protocol/openid-connect/token"  # Caminho de healthcheck do Keycloak
#     },
#   ]

#   vpc_config_private_app_subnet_ids = module.networking.private_subnet_ids
#   vpc_config_public_subnet_ids      = module.networking.public_subnet_ids
#   alb_listener_arn                  = module.ecs_cluster.alb_listener_arn
#   ecs_cluster_id                    = module.ecs_cluster.ecs_cluster_id
#   dns_zone_name                     = var.dns_zone_name

#   # Passando variáveis de ambiente para o Keycloak
#   service_environment = {
#   DB_VENDOR    = "postgres"
#   DB_ADDR      = "jdbc:postgresql://${module.database.aws_rds_instance_postgresql_endpoint}:5432/${var.initial_db_name}"
#   # Endereço do endpoint do Aurora
#   DB_PORT      = "5432"  # Porta do PostgreSQL
#   DB_DATABASE  = var.initial_db_name  # Nome do banco de dados no Aurora
#   DB_USER      = var.master_username  # Usuário do banco de dados
#   DB_PASSWORD  = var.master_password  # Senha do banco de dados
#   KC_HOSTNAME  = "keycloak-keycloak-example.ms.sandbox.neuai.com.br"  # Defina o hostname correto aqui
#   KEYCLOAK_PROXY = "edge" # Configuração para proxy reverso (como ALB)
#   KEYCLOAK_ADMIN = "admin"
#   KEYCLOAK_ADMIN_PASSWORD = "admin"
# }


#   depends_on = [module.networking, module.ecs_cluster]
# }

# output "keycloak_service_url_2" {
#   value = module.keycloak_ecs_service.microservice_url  # URL do serviço Keycloak
# }
