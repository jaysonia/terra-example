# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A unique name for your project, used as a prefix for resources."
  type        = string
  default     = "web-app"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "eng"
}

variable "app_container_port" {
  description = "The port your application container listens on."
  type        = number
  default     = 80
}

variable "app_health_check_path" {
  description = "The path for the ALB health check."
  type        = string
  default     = "/"
}

variable "app_desired_count" {
  description = "The desired number of running tasks for the service."
  type        = number
  default     = 1
}

variable "fargate_cpu" {
  description = "The CPU units for the Fargate task (e.g., 256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "The memory (in MiB) for the Fargate task (e.g., 512, 1024, 2048, 4096, 8192, 16384, 30720)."
  type        = number
  default     = 512
}

variable "app_environment_variables" {
  description = "A map of environment variables to pass to the application container."
  type        = map(string)
  default = {
    ENV = "PROD",
    APPLICATION = "WEB-APP"
  }
}

variable "ssl_certificate" {
  description = "The ARN of the ACM certificate for HTTPS listener."
  type        = string
  default     = ""
}