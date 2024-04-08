# NUWE Hack - CLOUD - TERRAFORM

# ServerlessTasker

## Description

ServerlessTasker is a serverless solution that facilitates task management via an API interface. This project is designed to run locally using LocalStack, providing a complete testing environment for AWS services such as Lambda, DynamoDB, and S3.

## Prerequisites

- Docker and Docker Compose
- AWS CLI, configured to target LocalStack
- Terraform
- Python 3.x and `pip`
- Virtualenv (optional but recommended for Python package management)

## Running LocalStack

LocalStack provides a local development environment that mimics the AWS cloud, allowing you to deploy AWS-like services on your local machine.

To start LocalStack, navigate to the directory containing your docker-compose.yml file and run the following command:

```bash
docker-compose up -d
```

### Initializing Terraform

Navigate to the `Terraform` directory where your Terraform configuration files are located, such as `main.tf`, and perform the following steps:

Initialize Terraform:

```bash
terraform init
```

Apply the Terraform configuration to create the resources in LocalStack using 'dev' stage:

```bash
terraform apply
```

Or you can use the following command to create the resources in LocalStack using another stage, such as 'prod':

```bash
terraform apply -var 'stage=prod'
```

## API Endpoints

The API provides two endpoints for managing tasks:

### Create Task

#### Endpoint Description

This endpoint is designed for creating a new task. It is accessed through a POST request and accepts a JSON body with two fields: task_name and cron_expression.

#### HTTP Method

`POST`

#### URL

Given the recommended URL structure for LocalStack and API Gateway, the URL might follow this format:

```bash
http://<api_id>.execute-api.localhost.localstack.cloud:4566/<stage_name>/createtask
```

Replace <api_id> with your API's ID in LocalStack and <stage_name> with the name of the stage where your API is deployed.

#### Required Body

The request should include a JSON object in the body with the following properties:

task_name: A string representing the name of the task.
cron_expression: A string representing the cron schedule expression for the task, determining how frequently the task should be executed.

#### Example Body

```json
{
  "task_name": "task1",
  "cron_expression": "0 * * * *"
}
```

### List Tasks

#### Endpoint Description

This endpoint offers a way to retrieve a list of all stored tasks. It requires a GET request and does not necessitate any request body, as it aims to return a list of tasks from the DynamoDB table.

#### HTTP Method

`GET`

#### URL

Adhering to the standard URL structure for accessing services via LocalStack, the URL might be:

```bash
http://<api_id>.execute-api.localhost.localstack.cloud:4566/<stage_name>/listtasks
```

#### Required Body

No body is required for this request.

#### Response

The response will be a JSON array of tasks, each task object including properties such as task_id, task_name, and cron_expression.

## Scheduled Task

A scheduled task is executed every minute to create an item in the `taskstorage` S3 bucket.

## Cleaning Up

To stop LocalStack and remove all resources, run the following command:

```bash
terraform destroy
```

```bash
docker-compose down
```
