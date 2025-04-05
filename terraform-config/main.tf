
variable "account_id" {
  description = "AWS Account ID"
  default     = "123456789" # ←  actual AWS Account ID
}

#  Default vpc and the data block is for Fetching default vpc

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}



# Security Group for ECS
resource "aws_security_group" "ecs_sg" {
  name_prefix = "ecs-sg"

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS PostgreSQL 
resource "aws_db_instance" "medusa_db" {
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  username             = "medusa_user"
  password             = "medusa_pass"
  publicly_accessible  = false
  skip_final_snapshot  = true
  db_name              = "medusa"
}

# ECS Cluster
resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa"  // task definition versioning
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" //gives each container a unique ip in vpc to interact
  cpu                      = "512" 
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn //grants ecs permission to access ecr

  container_definitions = jsonencode([{
    name      = "medusa-backend",
    image     = "${var.account_id}.dkr.ecr.us-east-1.amazonaws.com/medusa-backend:latest",
    essential = true,
    portMappings = [{
      containerPort = 9000,
      protocol      = "tcp"
    }],
    environment = [
      {
        name  = "DATABASE_URL",
        value = "postgres://${aws_db_instance.medusa_db.username}:${aws_db_instance.medusa_db.password}@${aws_db_instance.medusa_db.endpoint}:5432/medusa"
      }
    ]
  }])
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Service ensures that specific number of task or containers should run with defined configuration in task definirion section

resource "aws_ecs_service" "medusa_service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}
