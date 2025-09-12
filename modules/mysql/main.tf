

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow MySQL access from trusted sources"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # শুধু trusted VPC / subnet access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}



resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "rds-subnet-group"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}



resource "aws_db_instance" "mydb" {
  identifier             = "my-database"
  allocated_storage      = var.rds_allocated_storage
  storage_type           = "gp2"
  engine                 = var.rds_engine
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  username               = var.rds_username
  password               = var.rds_password
  db_name                = "mydatabase"
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet.name
  skip_final_snapshot    = true
  apply_immediately      = true

  tags = {
    Name        = "my-rds"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
