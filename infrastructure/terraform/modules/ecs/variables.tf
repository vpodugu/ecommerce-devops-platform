# ECS Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "private_subnet_ids" {
  description = "IDs of private subnets"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID of ECS security group"
  type        = string
}

# Service Images
variable "user_service_image" {
  description = "User service Docker image"
  type        = string
}

variable "product_service_image" {
  description = "Product service Docker image"
  type        = string
}

variable "order_service_image" {
  description = "Order service Docker image"
  type        = string
}

variable "api_gateway_image" {
  description = "API Gateway Docker image"
  type        = string
}

# Service CPU and Memory
variable "user_service_cpu" {
  description = "CPU units for user service"
  type        = number
  default     = 256
}

variable "user_service_memory" {
  description = "Memory for user service"
  type        = number
  default     = 512
}

variable "product_service_cpu" {
  description = "CPU units for product service"
  type        = number
  default     = 256
}

variable "product_service_memory" {
  description = "Memory for product service"
  type        = number
  default     = 512
}

variable "order_service_cpu" {
  description = "CPU units for order service"
  type        = number
  default     = 256
}

variable "order_service_memory" {
  description = "Memory for order service"
  type        = number
  default     = 512
}

variable "api_gateway_cpu" {
  description = "CPU units for API gateway"
  type        = number
  default     = 256
}

variable "api_gateway_memory" {
  description = "Memory for API gateway"
  type        = number
  default     = 512
}

# Service Desired Count
variable "user_service_desired_count" {
  description = "Desired number of user service tasks"
  type        = number
  default     = 2
}

variable "product_service_desired_count" {
  description = "Desired number of product service tasks"
  type        = number
  default     = 2
}

variable "order_service_desired_count" {
  description = "Desired number of order service tasks"
  type        = number
  default     = 2
}

variable "api_gateway_desired_count" {
  description = "Desired number of API gateway tasks"
  type        = number
  default     = 2
}

# Target Group ARNs
variable "user_service_target_group_arn" {
  description = "Target group ARN for user service"
  type        = string
}

variable "product_service_target_group_arn" {
  description = "Target group ARN for product service"
  type        = string
}

variable "order_service_target_group_arn" {
  description = "Target group ARN for order service"
  type        = string
}

variable "api_gateway_target_group_arn" {
  description = "Target group ARN for API gateway"
  type        = string
}
