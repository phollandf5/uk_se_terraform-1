# Configure the AWS Provider
provider "aws" {
  version = "~> 2.0"
  region  = "eu-west-2"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> v2.0"

  name = "${var.prefix}-f5-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a"]
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]

  enable_nat_gateway = false

  tags = {
    Name = "arch-vpc-terraform"
  }
}

resource "aws_security_group" "f5" {
  name   = "${var.prefix}-f5"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-f5"
  }
}

resource "aws_network_interface" "f5-mgmt" {
  subnet_id   = module.vpc.public_subnets[0]
  private_ips = ["10.0.0.10"]
  security_groups = [ aws_security_group.f5.id ]

  tags = {
    Name = "${var.prefix}-f5-mgmt"
  }
}

resource "aws_eip" "f5-mgmt" {
  vpc                       = true
  network_interface         = aws_network_interface.f5-mgmt.id
  associate_with_private_ip = "10.0.0.10"
}

resource "aws_network_interface" "f5-public" {
  subnet_id   = module.vpc.public_subnets[1]
  private_ips = ["10.0.1.10"]
  security_groups = [ aws_security_group.f5.id ]

  tags = {
    Name = "${var.prefix}-f5-public"
  }
}

resource "aws_eip" "f5-public" {
  vpc                       = true
  network_interface         = aws_network_interface.f5-public.id
  associate_with_private_ip = "10.0.1.10"
}

resource "aws_instance" "big-ip" {
  ami           = "ami-0fe284d68b7936ab6"
  instance_type = "m5.xlarge"
  key_name      = var.ssh_key_name

  network_interface {
    network_interface_id = aws_network_interface.f5-mgmt.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.f5-public.id
    device_index         = 1
  }

  tags = {
    Name = "${var.prefix}-f5"
  }
}


