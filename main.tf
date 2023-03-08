### Module Main

## Provider
provider "aws" {
  region = var.aws_region
}

# ## STATE SUR S3 BUCKET
# terraform {
#   backend "s3" {
#     # Nom du bucket
#     bucket = "adrien-isri-upjv"

#     # Chemin où on veut mettre le fichier dans le bucket
#     key = "terraform/vpc/terraform.tfstate"

#     # Region du bucket
#     region = "us-east-1"

#     # Nom de la dynamo DB pour lock l'accès au fichier
#     dynamodb_table = "lock-s3"
#   }
# }

## VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = "${var.vpc_name}-vpc"
  }
}

## sous-réseaux publiques
resource "aws_subnet" "public_subnet" {
  /*permet de boucler sur toutes les valeurs de la variable azs (les zones d'accessibilité, configurer dans le fichier variables.tf)*/
  for_each   = var.azs
  vpc_id     = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.cidr_block, 4, each.value)

  availability_zone = "${var.aws_region}${each.key}"

  # Ajoute une adresse IP public au subnet (par défaut = false)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${var.aws_region}${each.key}"
  }
}

## sous-réseaux privés
resource "aws_subnet" "private_subnet" {
  for_each   = var.azs
  vpc_id     = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.cidr_block, 4, 15 - each.value)

  availability_zone = "${var.aws_region}${each.key}"

  tags = {
    Name = "${var.vpc_name}-private-${var.aws_region}${each.key}"
  }
}

## Gateway pour que le VPC communique avec internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

## AMI pour une instance EC2 nat
data "aws_ami" "ami_nat" {
  most_recent = true
  name_regex  = "^amzn-ami-vpc-nat-2018.03.0.2021*"
  owners      = ["amazon"]
}

## Security group
resource "aws_security_group" "secu_group" {
  name        = "${var.vpc_name}-security-group"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-security-group"
  }
}

## Security group rules
resource "aws_security_group_rule" "rule_ingress_nat" {
  # ingress = entrée
  type = "ingress"

  # Accepte le port 22 en entrée
  from_port = 22
  to_port   = 22

  # En TCP
  protocol = "tcp"

  # Depuis toutes les adresses
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.secu_group.id
}

resource "aws_security_group_rule" "rule_ingress_private" {
  type = "ingress"

  # Accepte tous les ports et tous les protocoles en entrée
  from_port = -1
  to_port   = -1
  protocol  = -1

  # Provenant du même réseau 
  cidr_blocks       = [var.cidr_block]
  security_group_id = aws_security_group.secu_group.id
}

resource "aws_security_group_rule" "rule_egress_nat" {
  # egress = sortie
  type = "egress"

  # Accepte tous les ports et protocoles en sortie
  from_port = -1
  to_port   = -1
  protocol  = -1

  # Vers toutes les sorties
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.secu_group.id
}

## clés ssh
resource "aws_key_pair" "deployer" {
  key_name   = "${var.vpc_name}-deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDASSV09VJRqNOIRZCqQGa9pTOsB278p2KUnw+KsoU9N3GFwlk4sbYhKbN//PLGeeUpI/Hm085u+MMmKISA/W1+/lNKh4/zIUHbLuwRw8WKJRsdYXk223xQri75O3LgbtknFXYfEugwXppMZhbiL9REk/Hr0VcnXWtVzzV6Gr3QGHwh8yhh8QldDvHMBhNYJ9CJwaSU3SeV+F30m1qlIo8DBnQb90J0NNmTgDPEal6agam9qy8tHuDbHm4Ksagf+yZlgsn1zEzsyVqy08GWoNozh3d1YGIN+tTPPrRMCyYIfCH5nBzggfg+vjZHTmlK8lgTijqRbQFpMw2Vl0M5iYawC8TJdfIWRNoG6tQ3pzYihIrgGM2lyB12dRqpDxj/YwsgpTzWyygnq5/8wbuJpwwxClhX1kzNh4Tl/HabegqHXXoycQesHKwWRfvcMUerwRPJdS2ThD/s8/tDpZQG6s0QmyoxrILj/0+uKN5ne7yD7MqN7uVqC0JWtLsI04ZD62E= adrien@ideapad"
}

## instance ec2 nat
resource "aws_instance" "ec2_nat" {
  for_each               = var.azs
  ami                    = data.aws_ami.ami_nat.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet[each.key].id
  vpc_security_group_ids = [aws_security_group.secu_group.id]
  source_dest_check      = false
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "${var.vpc_name}-nat-${var.aws_region}${each.key}"
    Role = "NAT"
  }
}

## EIP pour les nat (réservation d'une IP publique)
resource "aws_eip" "eip_nat" {
  for_each = var.azs
  vpc      = true
}

## Association des IPs aux instances
resource "aws_eip_association" "eip_association_nat" {
  for_each      = var.azs
  instance_id   = aws_instance.ec2_nat[each.key].id
  allocation_id = aws_eip.eip_nat[each.key].id
}

## Table de routage privées
resource "aws_route_table" "route_table_private" {
  for_each = var.azs
  vpc_id   = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-private-${var.aws_region}${each.key}"
  }
}

## Routes privées
resource "aws_route" "route_private" {
  for_each               = var.azs
  route_table_id         = aws_route_table.route_table_private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.ec2_nat[each.key].primary_network_interface_id
}

## Table de routage publique
resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-public"
  }
}

## Routes publique
resource "aws_route" "route_public" {
  route_table_id         = aws_route_table.route_table_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

## Association des routes et des subnets
resource "aws_route_table_association" "route_table_association_private" {
  for_each       = var.azs
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.route_table_private[each.key].id
}

resource "aws_route_table_association" "route_table_association_public" {
  for_each       = var.azs
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.route_table_public.id
}
