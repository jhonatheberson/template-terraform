locals {
  availability_zones = [for s in data.aws_subnet.private_data_subnets : s.availability_zone]
  tags               = merge(var.tags_to_append, { Environment = var.environment })
  vpc_id             = data.aws_subnet.private_data_subnets[0].vpc_id
  db_domain_name     = "postgres.${var.environment}.${data.aws_route53_zone.dns.name}"
}

output "availability_zones" {
  value = local.availability_zones
}

resource "aws_db_subnet_group" "default" {
  name       = "default_db_subnet_group_postgres_${var.environment}"
  subnet_ids = var.vpc_config_private_data_subnet_ids

  tags = merge(local.tags, { Name = "default_db_subnet_group_postgres_${var.environment}" })
}

resource "aws_security_group" "allow_postgres" {
  name        = "allow_postgres_${var.environment}"
  description = "Allow Postgres inbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow Postgres from your IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Troque MEU_IP pelo seu IP público
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "allow_postgres_${var.environment}" })
}

output "aws_security_group_postgres" {
  value = aws_security_group.allow_postgres.id
}

# Definição do banco de dados PostgreSQL acessível pelo DBeaver
resource "aws_db_instance" "postgresql" {
  identifier             = "postgres-${var.environment}"
  engine                = "postgres"
  engine_version        = "17.1"
  instance_class        = "db.t3.micro"  # Elegível ao Free Tier
  allocated_storage     = 20  # Free Tier cobre até 20GB
  storage_type          = "gp2"
  db_name               = var.initial_db_name
  username             = var.master_username
  password             = var.master_password
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.allow_postgres.id]
  # backup_retention_period = 7
  multi_az             = false  # Free Tier não cobre Multi-AZ
  publicly_accessible  = true  # Permite acesso externo
  skip_final_snapshot  = true

  tags = merge(local.tags, { Name = "postgres_db_${var.environment}" })
}

# Registro DNS no Route53
resource "aws_route53_record" "database" {
  zone_id = data.aws_route53_zone.dns.zone_id
  name    = local.db_domain_name
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.postgresql.address]
}

output "aws_rds_instance_postgresql_endpoint" {
  value = aws_db_instance.postgresql.address
}
