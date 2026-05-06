# ALB SG — internet-facing
resource "aws_security_group" "alb" {
  name        = "${var.devops_practice}-${var.environment}-alb-sg"
  description = "ALB ingress from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "${var.devops_practice}-${var.environment}-alb-sg"
  }
}

# ECS tasks SG — only ALB can reach app port
resource "aws_security_group" "ecs" {
  name        = "${var.devops_practice}-${var.environment}-ecs-sg"
  description = "ECS tasks - traffic from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.devops_practice}-${var.environment}-ecs-sg"
  }
}

# RDS SG — only ECS tasks can reach Postgres
resource "aws_security_group" "rds" {
  name        = "${var.devops_practice}-${var.environment}-rds-sg"
  description = "Postgres from ECS only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.devops_practice}-${var.environment}-rds-sg"
  }
}