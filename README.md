# Medusa Backend Deployment on AWS Fargate using Terraform and GitHub Actions

## 📄 Problem Statement: Real-World Scenario

Let’s understand this with a real-world story. In an organization, there's a backend developer named **A** who is responsible for building backend applications. Suppose A sets up the backend for a website using [Medusa](https://medusajs.com/) and containers it using Docker. A then pushes this Docker image to **Amazon ECR (Elastic Container Registry)** — a service just like Docker Hub but hosted on AWS.

Now comes the role of the **DevOps engineer**, who ensures that the backend gets deployed reliably and efficiently. Instead of manually configuring infrastructure, they use **Terraform** to define everything as code.

They then deploy the Medusa backend on **AWS ECS (Elastic Container Service)** using **Fargate**. Fargate lets you run containers without managing servers — it's like running apps serverlessly with AWS Lambda, but built for containers.

**ECS can run containers in two ways:**

- On EC2 instances
- On Fargate (serverless)

The application, once deployed, is accessible via a defined endpoint (like `localhost:9000/app` locally). To ensure smooth updates, the DevOps engineer also sets up a **CI/CD pipeline using GitHub Actions**. This way, whenever code is pushed to GitHub, a new Docker image is built, pushed to ECR, and deployed to ECS automatically.

---

## ✅ Step-by-Step Flow

### ① Developer's Responsibility

**Developer A** sets up the backend using Medusa and writes a `Dockerfile` in their codebase. Then pushes the image to ECR:

```bash
# Login to ECR
aws ecr get-login-password --region <your-region> \
  | docker login --username AWS \
  --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Create ECR repository (one time only)
aws ecr create-repository \
  --repository-name medusa-backend \
  --region <your-region>

# Build Docker image
docker build -t medusa-backend .

# Tag the image for ECR
docker tag medusa-backend:latest \
  <account-id>.dkr.ecr.<region>.amazonaws.com/medusa-backend:latest

# Push image to ECR
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/medusa-backend:latest
```

> ✅ **Before this, make sure AWS CLI is configured using:**

```bash
aws configure
```

And provide the access key ID, secret key, region (e.g. `us-east-1`) and output format (`json`)

---

### ② DevOps Engineer's Responsibility

The DevOps engineer writes Terraform configuration to provision the required infrastructure:

- **RDS** for PostgreSQL (Medusa's DB)
- **ECS Cluster & Fargate Tasks** for running the container
- **ECR repo**, **security groups**, **VPC/subnets**

The Terraform files include:

- `main.tf`: Resources
- `provider.tf`: AWS provider config
- `variables.tf`: Variables (optional)

> Example stack includes:

- AWS RDS PostgreSQL
- AWS ECS Cluster (with Task Definition for Docker image)
- Fargate Launch Type (no EC2)
- Security Group to allow access

---

### ③ GitHub Actions CI/CD Pipeline

A GitHub Actions workflow (e.g. `.github/workflows/deploy.yml`) is created to:

1. Trigger on push to `main` branch
2. Build Docker image
3. Log in to ECR
4. Push the new image
5. Trigger ECS service update using latest image

This ensures **automated deployments** with each code push.

---

## 📈 Additional Considerations for Production-Like Setup

To make the application function like a real-world production application, consider the following things can be considered as well:

### 🌐 Custom Domain

- Use **Amazon Route 53** to manage your DNS
- Create a record (A or CNAME) pointing your domain to the **Application Load Balancer (ALB)** in front of ECS service

### 🏛 HTTPS (TLS/SSL)

- Use **AWS Certificate Manager (ACM)** to issue free SSL/TLS certificates
- Attach the certificate to your ALB to enable HTTPS
- Redirect HTTP to HTTPS if needed

### 🚫 Private Environment Variables

- Use **AWS Secrets Manager** or **SSM Parameter Store** for storing DB credentials and secrets

### ⏰ Logging & Monitoring

- Enable **CloudWatch Logs** for your container
- Set up **alarms** for failures or high CPU/memory

### ⚖️ Scalability

- Define auto-scaling policies for ECS service
- Set min/max desired task count

---

## 📚 Summary

- Developer A builds and pushes the backend image to ECR
- DevOps engineers use Terraform to provision infra and deploy it via ECS + Fargate
- A CI/CD pipeline using GitHub Actions ensures automatic re-deployment of updated versions
- Additional production-grade practices like domain setup, HTTPS, secrets management, and monitoring help bring this closer to a real-world app setup

This setup provides a modern, serverless, and scalable way to deploy backend services without worrying about underlying servers.

---



