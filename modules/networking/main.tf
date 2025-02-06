locals {
  vpc_network = "10.0.0.0/16"
  tags        = merge(var.tags_to_append, { Environment = var.environment })
  az_subnets  = {
    "${var.region}a" = {
      "public"      = "10.0.0.0/24"
      "private_app" = "10.0.1.0/24"
    }
    "${var.region}b" = {
      "public"      = "10.0.66.0/24"
      "private_app" = "10.0.62.0/24"
    }
  }
}

# Criar VPC
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_network
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "vpc_${var.environment}" })
}

# Criar Subnets Públicas
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.az_subnets["${var.region}a"].public
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "subnet_public_a_${var.environment}" })
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.az_subnets["${var.region}b"].public
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "subnet_public_b_${var.environment}" })
}

# Criar Subnets Privadas (Duas para RDS)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.az_subnets["${var.region}a"].private_app
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = false
  tags = merge(local.tags, { Name = "subnet_private_a_${var.environment}" })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.az_subnets["${var.region}b"].private_app
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = false
  tags = merge(local.tags, { Name = "subnet_private_b_${var.environment}" })
}

# Internet Gateway e Tabela de Rotas Pública
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "igw_${var.environment}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.tags, { Name = "rt_public_${var.environment}" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id     = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id     = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Route Table Privada (sem acesso à internet)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "rt_private_${var.environment}" })
}

resource "aws_route_table_association" "private_a" {
  subnet_id     = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id     = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id] # Agora são duas subnets privadas!
}
