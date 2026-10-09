resource "aws_security_group" "elasticache_security_group" {
  name        = "${var.environment}-priv-01-redis"
  description = "Redis Elasticache Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
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
    Name = "${var.environment}-priv-01-redis"
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "${var.project_name}-${var.environment}-RedisSubnetGroup"
  description = "Cache Subnet Group"
  subnet_ids  = [var.private_subnet1, var.private_subnet2]
}

resource "aws_elasticache_replication_group" "redis_replication_group" {
  replication_group_id          = "${var.project_name}-${var.environment}-redis"
  description                   = "${var.project_name}-${var.environment}-redis"
  engine                        = "valkey"
  engine_version                = "8.2"
  node_type                     = "cache.t3.micro"
  parameter_group_name          = "default.valkey8"
  subnet_group_name             = aws_elasticache_subnet_group.redis_subnet_group.name
  port                          = 6379
  num_cache_clusters            = 1
  automatic_failover_enabled    = false
  multi_az_enabled              = false
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auth_token                    = "${var.project_name}^Appetiser2023"

  security_group_ids = [aws_security_group.elasticache_security_group.id]

  tags = {
    Name = "${var.environment}"
  }
}