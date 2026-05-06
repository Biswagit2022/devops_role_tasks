variable "devops_practice" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "target_group_arn" { type = string }
variable "alb_listener_arn" { type = string }

variable "container_image" { type = string }
variable "container_port" { type = number }
variable "task_cpu" { type = number }
variable "task_memory" { type = number }
variable "desired_count" { type = number }

variable "db_endpoint" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}