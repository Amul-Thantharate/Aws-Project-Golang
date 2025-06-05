
resource "aws_vpc" "vpc_east" {
  provider    = aws.east
  cidr_block = "10.10.0.0/16"
  tags = { Name = "vpc-east" }
}

resource "aws_subnet" "subnet_east" {
  provider              = aws.east
  vpc_id                = aws_vpc.vpc_east.id
  cidr_block            = "10.10.1.0/24"
  availability_zone     = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-east" }
}

resource "aws_internet_gateway" "igw_east" {
  provider = aws.east
  vpc_id    = aws_vpc.vpc_east.id
  tags      = { Name = "igw-east" }
}

resource "aws_route_table" "rt_east" {
  provider = aws.east
  vpc_id    = aws_vpc.vpc_east.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_east.id
  }
  tags = { Name = "rt-east" }
}

resource "aws_route_table_association" "rta_east" {
  provider       = aws.east
  subnet_id      = aws_subnet.subnet_east.id
  route_table_id = aws_route_table.rt_east.id
}

resource "aws_instance" "east_ec2" {
  provider                    = aws.east
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_east.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_east.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y traceroute tcpdump
              ping -c 5 10.20.1.10 # Replace with West's EC2 Private IP (or leave to fail initially)
              EOF

  tags = { Name = "east-ec2" }
}

################################
# REGION: us-west-2
################################

resource "aws_vpc" "vpc_west" {
  provider    = aws.west
  cidr_block = "10.20.0.0/16"
  tags = { Name = "vpc-west" }
}

resource "aws_subnet" "subnet_west" {
  provider              = aws.west
  vpc_id                = aws_vpc.vpc_west.id
  cidr_block            = "10.20.1.0/24"
  availability_zone     = "us-west-2a"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-west" }
}

resource "aws_internet_gateway" "igw_west" {
  provider = aws.west
  vpc_id    = aws_vpc.vpc_west.id
  tags      = { Name = "igw-west" }
}

resource "aws_route_table" "rt_west" {
  provider = aws.west
  vpc_id    = aws_vpc.vpc_west.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_west.id
  }
  tags = { Name = "rt-west" }
}

resource "aws_route_table_association" "rta_west" {
  provider       = aws.west
  subnet_id      = aws_subnet.subnet_west.id
  route_table_id = aws_route_table.rt_west.id
}

resource "aws_instance" "west_ec2" {
  provider                    = aws.west
  ami                         = "ami-0892d3c7ee96c0bf7" # Amazon Linux 2 (west region)
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_west.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_west.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y traceroute tcpdump
              ping -c 5 10.10.1.10 # Replace with East's EC2 Private IP (or leave to fail initially)
              EOF

  tags = { Name = "west-ec2" }
}

################################
# Security Groups
################################

resource "aws_security_group" "sg_east" {
  provider = aws.east
  name    = "sg-east"
  vpc_id  = aws_vpc.vpc_east.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ICMP Ping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

resource "aws_security_group" "sg_west" {
  provider = aws.west
  name    = "sg-west"
  vpc_id  = aws_vpc.vpc_west.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ICMP Ping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

################################
# TRANSIT GATEWAY (created in one region - us-east-1 in this example)
################################

resource "aws_ec2_transit_gateway" "tgw_east" {
  provider = aws.east #  Important: Choose the region where you want the TGW to reside

  description                         = "Multi-region TGW"
  default_route_table_association = "disable" #  Important: Disable default association
  default_route_table_propagation = "disable" #  Important: Disable default propagation
  tags = {
    Name = "tgw-east"
  }
}

################################
# TRANSIT GATEWAY VPC ATTACHMENTS
################################

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach_east" {
  provider                    = aws.east
  subnet_ids                  = [aws_subnet.subnet_east.id]
  transit_gateway_id          = aws_ec2_transit_gateway.tgw_east.id
  vpc_id                      = aws_vpc.vpc_east.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = true

  tags = { Name = "tgw-attach-east" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach_west" {
  provider                    = aws.west
  subnet_ids                  = [aws_subnet.subnet_west.id]
  transit_gateway_id          = aws_ec2_transit_gateway.tgw_east.id  #Use the *same* TGW ID
  vpc_id                      = aws_vpc.vpc_west.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = true

  tags = { Name = "tgw-attach-west" }
}

################################
# TRANSIT GATEWAY ROUTING
################################

resource "aws_ec2_transit_gateway_route" "tgw_route_east_to_west" {
  provider                        = aws.east
  destination_cidr_block        = aws_vpc.vpc_west.cidr_block # Route to West VPC
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw_east.default_route_table_id # Replace with TGW Route Table ID if you created a custom one
  transit_gateway_attachment_id   = aws_ec2_transit_gateway_vpc_attachment.tgw_attach_west.id # Use the attachment ID for the *destination* VPC.
}

resource "aws_ec2_transit_gateway_route" "tgw_route_west_to_east" {
  provider                        = aws.east # Must match the TGW's provider
  destination_cidr_block        = aws_vpc.vpc_east.cidr_block # Route to East VPC
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw_east.default_route_table_id # Replace with TGW Route Table ID if you created a custom one
  transit_gateway_attachment_id   = aws_ec2_transit_gateway_vpc_attachment.tgw_attach_east.id # Use the attachment ID for the *destination* VPC.
}

################################
# TRANSIT GATEWAY ROUTE TABLE ASSOCIATIONS
################################

resource "aws_ec2_transit_gateway_route_table_association" "tgw_rta_east" {
  provider                   = aws.east
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attach_east.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw_east.default_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_rta_west" {
  provider                   = aws.west
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attach_west.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw_east.default_route_table_id
}
