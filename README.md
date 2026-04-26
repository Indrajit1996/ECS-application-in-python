# Flask ECS Application with Dynatrace Integration

A production-ready Flask application running on AWS ECS Fargate with Dynatrace OneAgent monitoring integration.

## Architecture Overview

- **Application**: Flask web application with Uvicorn ASGI server
- **Container**: Docker with Python 3.9
- **Orchestration**: AWS ECS Fargate
- **Load Balancer**: Application Load Balancer (ALB)
- **Monitoring**: Dynatrace OneAgent
- **Logging**: CloudWatch Logs
- **Secrets**: AWS Secrets Manager

## Project Structure

```
.
├── app.py                          # Flask application
├── asgi.py                         # ASGI entry point for Uvicorn
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container definition with Dynatrace
├── ecs-task-definition.json        # ECS task definition
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Variable definitions
│   ├── outputs.tf                  # Output values
│   └── terraform.tfvars.example    # Example configuration
├── scripts/                        # Deployment scripts
│   ├── build-and-push.sh          # Build and push Docker image
│   └── deploy.sh                  # Deploy to ECS
└── README.md                       # This file
```

## Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **Docker** installed and running

3. **Terraform** (v1.0+) installed
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

4. **Dynatrace Account** with:
   - Environment ID (e.g., `abc12345`)
   - API Token with permissions:
     - `PaaS integration - Installer download`
     - `Log content access`

## Setup Instructions

### Step 1: Configure Dynatrace Credentials

1. Get your Dynatrace credentials:
   - **Environment ID**: Found in Dynatrace URL (`https://{ENVIRONMENT_ID}.live.dynatrace.com`)
   - **API Token**: Generate from Settings > Integration > Platform as a Service

2. Store credentials in AWS Secrets Manager (will be done via Terraform):
   ```bash
   # These will be created by Terraform, but you need to set the values
   ```

### Step 2: Deploy Infrastructure with Terraform

1. Navigate to the terraform directory:
   ```bash
   cd terraform
   ```

2. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your values:
   ```hcl
   aws_region                = "us-east-1"
   project_name              = "flask-ecs-app"
   environment               = "production"
   dynatrace_api_token       = "your-dynatrace-api-token"
   dynatrace_environment_id  = "your-environment-id"
   ```

4. Initialize Terraform:
   ```bash
   terraform init
   ```

5. Review the plan:
   ```bash
   terraform plan
   ```

6. Apply the configuration:
   ```bash
   terraform apply
   ```

   This will create:
   - VPC with public subnets
   - Application Load Balancer
   - ECS Cluster and Service
   - ECR Repository
   - Security Groups
   - IAM Roles
   - CloudWatch Log Group
   - Secrets Manager secrets

7. Note the outputs:
   ```bash
   terraform output
   ```

### Step 3: Store Dynatrace Secrets

After Terraform creates the secrets, add the actual values:

```bash
# Get the secret ARNs from Terraform output
DYNATRACE_TOKEN_SECRET=$(terraform output -raw dynatrace_api_token_secret_arn)
DYNATRACE_ENV_SECRET=$(terraform output -raw dynatrace_environment_id_secret_arn)

# Update the secrets with actual values
aws secretsmanager put-secret-value \
  --secret-id $DYNATRACE_TOKEN_SECRET \
  --secret-string "your-dynatrace-api-token"

aws secretsmanager put-secret-value \
  --secret-id $DYNATRACE_ENV_SECRET \
  --secret-string "your-environment-id"
```

### Step 4: Build and Push Docker Image

1. Get ECR repository URL from Terraform output:
   ```bash
   ECR_URL=$(terraform output -raw ecr_repository_url)
   ```

2. Authenticate Docker to ECR:
   ```bash
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin $ECR_URL
   ```

3. Build the Docker image:
   ```bash
   cd ..  # Go back to project root
   docker build -t flask-ecs-app .
   ```

4. Tag and push the image:
   ```bash
   docker tag flask-ecs-app:latest $ECR_URL:latest
   docker push $ECR_URL:latest
   ```

### Step 5: Deploy to ECS

The ECS service is already created by Terraform. To update the service with the new image:

```bash
# Get cluster and service names
CLUSTER_NAME=$(cd terraform && terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(cd terraform && terraform output -raw ecs_service_name)

# Force new deployment
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment
```

### Step 6: Verify Deployment

1. Get the ALB DNS name:
   ```bash
   ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)
   echo "Application URL: http://$ALB_DNS"
   ```

2. Test the application:
   ```bash
   # Health check
   curl http://$ALB_DNS/health

   # Root endpoint
   curl http://$ALB_DNS/

   # Data endpoint
   curl http://$ALB_DNS/api/data
   ```

3. Verify in Dynatrace:
   - Log into your Dynatrace dashboard
   - Navigate to "Hosts" or "Services"
   - You should see your ECS tasks being monitored

4. Check CloudWatch Logs:
   ```bash
   aws logs tail /ecs/flask-ecs-app --follow
   ```

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint (used by ALB)
- `GET /api/data` - Sample data endpoint
- `POST /api/data` - Create data endpoint

## Monitoring with Dynatrace

### What Dynatrace Monitors

1. **Application Performance**:
   - Response times
   - Request rates
   - Error rates
   - Throughput

2. **Infrastructure**:
   - CPU usage
   - Memory consumption
   - Network traffic
   - Container metrics

3. **Logs**:
   - Application logs
   - Error logs
   - Access logs

### Accessing Dynatrace Dashboards

1. Log into Dynatrace: `https://{YOUR_ENVIRONMENT_ID}.live.dynatrace.com`
2. Navigate to:
   - **Services**: View application performance
   - **Hosts**: View container infrastructure
   - **Logs**: View application logs
   - **Problems**: View detected issues

## Local Development

Run the application locally:

```bash
# Install dependencies
pip install -r requirements.txt

# Run with Flask (development)
python app.py

# Run with Uvicorn (production-like)
uvicorn asgi:asgi_app --host 0.0.0.0 --port 8080 --reload
```

Access at: http://localhost:8080

## Deployment Scripts

### Automated Build and Push

```bash
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh
```

### Automated Deployment

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## Scaling

### Manual Scaling

Update desired count in `terraform/variables.tf`:

```hcl
variable "desired_count" {
  default = 4  # Change from 2 to 4
}
```

Then apply:

```bash
cd terraform
terraform apply
```

### Auto Scaling (Optional)

Add auto-scaling configuration to `terraform/main.tf`:

```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

## Troubleshooting

### Container Won't Start

Check CloudWatch Logs:
```bash
aws logs tail /ecs/flask-ecs-app --follow
```

### Dynatrace Not Reporting

1. Verify secrets are set:
   ```bash
   aws secretsmanager get-secret-value --secret-id flask-ecs-app/dynatrace/api-token
   aws secretsmanager get-secret-value --secret-id flask-ecs-app/dynatrace/environment-id
   ```

2. Check container logs for Dynatrace OneAgent installation:
   ```bash
   aws logs filter-pattern "Dynatrace" --log-group-name /ecs/flask-ecs-app
   ```

### Health Check Failing

1. Check task is running:
   ```bash
   aws ecs list-tasks --cluster flask-ecs-app-cluster --service-name flask-ecs-app-service
   ```

2. Verify security groups allow traffic on port 8080

3. Test health endpoint directly on container

## Cost Estimation

Approximate monthly costs (us-east-1):

- **ECS Fargate**: ~$30/month (2 tasks, 0.25 vCPU, 0.5 GB RAM)
- **Application Load Balancer**: ~$20/month
- **Data Transfer**: Variable
- **CloudWatch Logs**: ~$5/month (7 days retention)
- **Dynatrace**: Based on your plan

**Total**: ~$55-75/month (excluding Dynatrace)

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

Note: You may need to manually delete ECR images first:

```bash
aws ecr batch-delete-image \
  --repository-name flask-ecs-app \
  --image-ids imageTag=latest
```

## Security Best Practices

1. **Secrets Management**: All sensitive data stored in AWS Secrets Manager
2. **IAM Roles**: Least privilege access for ECS tasks
3. **Network Security**: Security groups restrict traffic
4. **Container Security**: Non-root user in container
5. **Image Scanning**: ECR scans images for vulnerabilities
6. **HTTPS**: Configure ACM certificate for ALB (recommended for production)

## CI/CD Integration

This project can be integrated with:

- **GitHub Actions**: See `.github/workflows/` (create as needed)
- **AWS CodePipeline**: Automated deployments
- **GitLab CI**: Docker build and deploy

## Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Dynatrace OneAgent Documentation](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-oneagent)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Uvicorn Documentation](https://www.uvicorn.org/)

## License

MIT License

## Support

For issues and questions:
- Open an issue in the repository
- Check CloudWatch Logs
- Review Dynatrace dashboards
