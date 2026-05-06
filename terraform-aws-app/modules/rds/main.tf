resource "aws_db_subnet_group" "main" {
  name       = "${var.devops_practice}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.devops_practice}-${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.devops_practice}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = false # flip to true for prod

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = true # flip to false for prod
  final_snapshot_identifier = "${var.devops_practice}-${var.environment}-final-snapshot"
  deletion_protection       = false # flip to true for prod

  performance_insights_enabled = true
  auto_minor_version_upgrade   = true

  tags = {
    Name = "${var.devops_practice}-${var.environment}-postgres"
  }
}