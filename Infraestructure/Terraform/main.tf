provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    s3             = "http://localhost:4566"
  }
}

# Variable for stage
variable "stage" {
  description = "The name of the deployment stage"
  type        = string
  default = "dev" 
}

# Create dynamodb table
resource "aws_dynamodb_table" "task_table" {
  name           = "TaskTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "task_id"
  attribute {
    name = "task_id"
    type = "S"
  }
}

# Create lambda function for create scheduled task service
resource "aws_lambda_function" "create_scheduled_task" {
  function_name = "createScheduledTask"
  handler       = "create_scheduled_task.handler"
  runtime       = "python3.8"  
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../lambda/create_scheduled_task.zip"
}

# Create IAM role for lambda function execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ]
  })
}

# Create api gateway
resource "aws_api_gateway_rest_api" "task_api" {
  name        = "TaskAPI"
  description = "API for creating tasks"
}

# Create resource for api gateway in /createtask endpoint
resource "aws_api_gateway_resource" "task_resource" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "createtask"
}

# Create method for api gateway
resource "aws_api_gateway_method" "task_method" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_resource.id
  http_method   = "POST" 
  authorization = "NONE" 
}

# Create integration for api gateway
resource "aws_api_gateway_integration" "task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_resource.id
  http_method             = aws_api_gateway_method.task_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_scheduled_task.invoke_arn
}

# Create deployment for api gateway
resource "aws_api_gateway_deployment" "task_api_deployment_dev" {
  depends_on  = [aws_api_gateway_integration.task_integration]
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  stage_name  = var.stage  # Cambia esto según tu entorno de despliegue
}

# Policy for lambda to access dynamodb
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "LambdaDynamoDBPolicy"
  description = "Dynamic policy to allow lambda to access dynamodb"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Resource = "arn:aws:dynamodb:tu-region:tu-cuenta:table/TuTablaDynamoDB"
      },
    ]
  })
}

# Attach policy to lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Service 2 - Read Scheduled Tasks

# Lambda function for read scheduled tasks service
resource "aws_lambda_function" "list_scheduled_task" {
  function_name = "listScheduledTask"
  handler       = "list_scheduled_task.handler"
  runtime       = "python3.8" 
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../lambda/list_scheduled_task.zip"
}

# Api gateway for list task service
resource "aws_api_gateway_resource" "list_task" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id  
  path_part   = "listtask"
}

# Method for list task service
resource "aws_api_gateway_method" "list_task_get" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.list_task.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integration for list task service
resource "aws_api_gateway_integration" "list_task_lambda" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.list_task.id
  http_method = aws_api_gateway_method.list_task_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_scheduled_task.invoke_arn
}

# Deployment for list task service
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.list_task_lambda,
  ]
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  stage_name = var.stage
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_integration.list_task_lambda))
  }
}

# Service 3 - Create Item in S3 every minute

# Lambda function for create item in s3 service
resource "aws_lambda_function" "execute_scheduled_task" {
  function_name = "executeScheduledTask"
  handler       = "execute_scheduled_task.handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec_role_with_s3.arn
  filename      = "../lambda/execute_scheduled_task.zip"
}

# Event rule for lambda function every minute
resource "aws_cloudwatch_event_rule" "execute_scheduled_task_event" {
  name                = "every-minute"
  description         = "Execute scheduled task every minute"
  schedule_expression = "rate(1 minute)"
}

# Event target for lambda function
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.execute_scheduled_task_event.name
  arn       = aws_lambda_function.execute_scheduled_task.arn
  target_id = "invokeLambdaFunction"
}

# Permission for event bridge to call lambda function
resource "aws_lambda_permission" "allow_eventbridge_to_call_execute_scheduled_task" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.execute_scheduled_task.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.execute_scheduled_task_event.arn
}

# S3 bucket for item task storage
resource "aws_s3_bucket" "task_storage" {
  bucket = "taskstorage"

  tags = {
    Name = "Task Storage"
  }
}

# Policy for lambda to access s3
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "lambda_s3_access_policy"
  description = "Permite a Lambda escribir en el bucket S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.task_storage.arn}/*"
        ]
      },
    ]
  })
}

# Create IAM role for lambda function execution with s3 access
resource "aws_iam_role" "lambda_exec_role_with_s3" {
  name = "LambdaExecRoleWithS3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com",
      },
      Effect = "Allow",
      Sid = "",
    }],
  })
}

# Attach policy to lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role_with_s3.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}



