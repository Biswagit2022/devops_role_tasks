variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "devops_practice" {
  description = "devops_practice, used as resource prefix"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs to deploy into"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# RDS
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type      = string
  default   = "appuser"
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
  # No default — pass via tfvars or env var TF_VAR_db_password
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_engine_version" {
  type    = string
  default = "16"
}

# ECS
variable "container_image" {
  description = "ECR or Docker Hub image URI"
  type        = string
  default     = "nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type    = number
  default = 512
}

variable "task_memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 2
}

# Access
variable "admin_ip_cidr" {
  description = "Your IP for any admin access (use a /32). Get it from https://checkip.amazonaws.com"
  type        = string
  default     = "0.0.0.0/0"
}