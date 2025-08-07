# ECS Module for E-Commerce Microservices Platform
# This module creates ECS cluster, services, and task definitions

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-ecs-cluster"
  })
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "user_service" {
  name              = "/ecs/${var.environment}-user-service"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-user-service-logs"
  })
}

resource "aws_cloudwatch_log_group" "product_service" {
  name              = "/ecs/${var.environment}-product-service"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-product-service-logs"
  })
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${var.environment}-order-service"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-order-service-logs"
  })
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/${var.environment}-api-gateway"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-api-gateway-logs"
  })
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.environment}-frontend"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-frontend-logs"
  })
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "user_service" {
  family                   = "${var.environment}-user-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.user_service_cpu
  memory                   = var.user_service_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "user-service"
      image = var.user_service_image

      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "3001"
        }
      ]

      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = aws_ssm_parameter.user_db_host.arn
        },
        {
          name      = "DB_USER"
          valueFrom = aws_ssm_parameter.user_db_user.arn
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_ssm_parameter.user_db_password.arn
        },
        {
          name      = "DB_NAME"
          valueFrom = aws_ssm_parameter.user_db_name.arn
        },
        {
          name      = "JWT_SECRET"
          valueFrom = aws_ssm_parameter.jwt_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.user_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.environment}-user-service-task-def"
  })
}

resource "aws_ecs_task_definition" "product_service" {
  family                   = "${var.environment}-product-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.product_service_cpu
  memory                   = var.product_service_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "product-service"
      image = var.product_service_image

      portMappings = [
        {
          containerPort = 3002
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "3002"
        }
      ]

      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = aws_ssm_parameter.product_db_host.arn
        },
        {
          name      = "DB_USER"
          valueFrom = aws_ssm_parameter.product_db_user.arn
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_ssm_parameter.product_db_password.arn
        },
        {
          name      = "DB_NAME"
          valueFrom = aws_ssm_parameter.product_db_name.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.product_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3002/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.environment}-product-service-task-def"
  })
}

resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.environment}-order-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.order_service_cpu
  memory                   = var.order_service_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "order-service"
      image = var.order_service_image

      portMappings = [
        {
          containerPort = 3003
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "3003"
        }
      ]

      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = aws_ssm_parameter.order_db_host.arn
        },
        {
          name      = "DB_USER"
          valueFrom = aws_ssm_parameter.order_db_user.arn
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_ssm_parameter.order_db_password.arn
        },
        {
          name      = "DB_NAME"
          valueFrom = aws_ssm_parameter.order_db_name.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.order_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3003/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.environment}-order-service-task-def"
  })
}

resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.environment}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_gateway_cpu
  memory                   = var.api_gateway_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api-gateway"
      image = var.api_gateway_image

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "USER_SERVICE_URL"
          value = "http://user-service:3001"
        },
        {
          name  = "PRODUCT_SERVICE_URL"
          value = "http://product-service:3002"
        },
        {
          name  = "ORDER_SERVICE_URL"
          value = "http://order-service:3003"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api_gateway.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.environment}-api-gateway-task-def"
  })
}

# ECS Services
resource "aws_ecs_service" "user_service" {
  name            = "${var.environment}-user-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user_service.arn
  desired_count   = var.user_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.user_service_target_group_arn
    container_name   = "user-service"
    container_port   = 3001
  }

  depends_on = [var.user_service_target_group_arn]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-user-service"
  })
}

resource "aws_ecs_service" "product_service" {
  name            = "${var.environment}-product-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product_service.arn
  desired_count   = var.product_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.product_service_target_group_arn
    container_name   = "product-service"
    container_port   = 3002
  }

  depends_on = [var.product_service_target_group_arn]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-product-service"
  })
}

resource "aws_ecs_service" "order_service" {
  name            = "${var.environment}-order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = var.order_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.order_service_target_group_arn
    container_name   = "order-service"
    container_port   = 3003
  }

  depends_on = [var.order_service_target_group_arn]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-order-service"
  })
}

resource "aws_ecs_service" "api_gateway" {
  name            = "${var.environment}-api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = var.api_gateway_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_gateway_target_group_arn
    container_name   = "api-gateway"
    container_port   = 8080
  }

  depends_on = [var.api_gateway_target_group_arn]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-api-gateway"
  })
}
