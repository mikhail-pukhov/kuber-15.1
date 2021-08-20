provider "aws" {
  region = "eu-north-1"
}  

resource "aws_vpc" "main" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.31.32.0/19"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "gw_nat" {
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "gw_nat"
  }

      depends_on = [aws_internet_gateway.gw]
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.31.96.0/19"
  
  tags = {
    Name = "Private"
  }  
}    
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "172.31.32.0/19"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route" "r" {
  route_table_id            = aws_route_table.r.id
  destination_cidr_block    = "172.31.96.0/19"
  nat_gateway_id = aws_nat_gateway.gw_nat.id
}


resource "aws_network_interface" "Ubuntu1" {
  subnet_id   = aws_subnet.public.id
  private_ips = ["172.16.32.7"]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "Ubuntu1" {
    ami = "ami-0767046d1677be5a0"
    instance_type = "t2.micro" 
    associate_public_ip_address = true

    network_interface {
    network_interface_id = aws_network_interface.Ubuntu1.id
    device_index         = 0
  }  
}


resource "aws_network_interface" "Ubuntu2" {
  subnet_id   = aws_subnet.private.id
  private_ips = ["172.16.96.7"]

  tags = {
    Name = "primary_network_interface1"
  }
}


resource "aws_instance" "Ubuntu2" {
    ami = "ami-0767046d1677be5a0"
    instance_type = "t2.micro" 

    network_interface {
    network_interface_id = aws_network_interface.Ubuntu2.id
    device_index         = 0
  }  
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "example" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.example.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.example.private_key_pem
  certificate_body = tls_self_signed_cert.example.cert_pem
} 

resource "aws_ec2_client_vpn_endpoint" "example" {
  description            = "terraform-clientvpn-example"
  server_certificate_arn = aws_acm_certificate.cert.arn
  client_cidr_block      = "172.16.160.0/19"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.cert.arn
  }

  connection_log_options {
    enabled               = true
  }
}

  
resource "aws_ec2_client_vpn_network_association" "example" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.example.id
  subnet_id              = aws_subnet.private.id
}

resource "aws_ec2_client_vpn_authorization_rule" "example" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.example.id
  target_network_cidr    = aws_subnet.private.cidr_block
  authorize_all_groups   = true
}
