resource "aws_db_parameter_group" "par_group" {
  name        = "${var.project_name}-${var.environment}-db-parameter-group"
  family      = "mysql8.4" 
  description = "Default parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }
}

resource "aws_security_group" "rds_security_group" {
  name        = "${var.environment}-priv-01-sql"
  description = "Database instances security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port                = 3306
    to_port                  = 3306
    protocol                 = "tcp"
    security_groups          = [var.ec2_instance_launch_template_sg]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-priv-01-sql"
  }
}

resource "aws_db_subnet_group" "rds_db_subnet_group" {
  name       = "${var.environment}-aws-dxl-database-subnet-group"
  description = "Subnet Group for mySQL database"
  subnet_ids = [var.private_subnet1, var.private_subnet2]

  tags = {
    Name ="rds-subnet-group"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "rds_key" {
  description = "KMS key for RDS encryption"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-rds"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_db_instance" "rds_db_instance" {
  identifier              = "${var.project_name}-${var.environment}"
  allocated_storage       = 20
  db_name                 = "${var.project_name}_${var.environment}"
  instance_class          = var.rds_instance
  engine                  = "mysql"
  engine_version          = "8.4.6"
  username                = var.master_username
  password                = aws_ssm_parameter.rds_password.value
  backup_retention_period = 7
  multi_az                = false
  auto_minor_version_upgrade = true
  publicly_accessible     = false
  storage_type            = "gp2"
  port                    = 3306
  copy_tags_to_snapshot   = true
  iam_database_authentication_enabled = false
  performance_insights_enabled = false
  deletion_protection     = false
  db_subnet_group_name    = aws_db_subnet_group.rds_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_security_group.id]
  max_allocated_storage   = 1000
  parameter_group_name    = aws_db_parameter_group.par_group.name
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds_key.arn
  ca_cert_identifier      = "rds-ca-ecc384-g1"
  apply_immediately = true
  skip_final_snapshot = true
}

resource "random_password" "rds_password" {
  length  = 16
  special = false
}

resource "aws_ssm_parameter" "rds_password" {
  name  = "/${var.project_name}/${var.environment}/rds_password"
  type  = "SecureString"
  value = random_password.rds_password.result
}
