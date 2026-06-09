provider "aws" {
  region = "us-east-1"
}

# ── VPC & Networking ────────────────────────────────────────
resource "aws_vpc" "bus_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "BusPassVPC" }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.bus_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "PublicSubnet1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.bus_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "PublicSubnet2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.bus_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.bus_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ── Security Groups ─────────────────────────────────────────
resource "aws_security_group" "ec2_sg" {
  name   = "ec2_sg"
  vpc_id = aws_vpc.bus_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "rds_sg"
  vpc_id = aws_vpc.bus_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── RDS MySQL ───────────────────────────────────────────────
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_db_instance" "bus_db" {
  identifier             = "buspassdb"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "buspassdb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Project = "HorizonTechX-Task3" }
}
resource "aws_key_pair" "bus_key" {
  key_name   = "HorizonTechX-Key"
  public_key = file("${path.module}/bus_key.pub")
}
# ── EC2 Instance ────────────────────────────────────────────
resource "aws_instance" "bus_server" {
  ami                         = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 Mumbai
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.bus_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install python3-pip python3-flask -y
    pip3 install flask flask-mysqldb
    echo "Server ready!" > /home/ubuntu/status.txt
  EOF

  tags = { Name = "BusPassServer" }
}

# ── Auto Scaling ────────────────────────────────────────────
resource "aws_launch_template" "bus_lt" {
  name_prefix   = "bus-pass-"
  image_id      = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 Mumbai
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "BusPassAutoScale" }
  }
}

resource "aws_autoscaling_group" "bus_asg" {
  desired_capacity  = 1
  min_size          = 1
  max_size          = 3
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  launch_template {
    id      = aws_launch_template.bus_lt.id
    version = "$Latest"
  }
}
