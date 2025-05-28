# terra-example

## Requirements
terraform cli
AWS cli
Docker

## Building with terraform

Setup environment variables, These can be set in github for building using CI/CD
```bash
export AWS_ACCESS_KEY_ID={id}
export AWS_SECRET_ACCESS_KEY={key}
```

Initialise terraform
```bash
terraform init
```
Optional validate the terraform configuration
```bash
terraform validate
```

Optional display what terraform will build
```bash
terraform plan
```

Build infrastruture will display the plan for commiting changes.
```bash
terraform apply
```

## Updating infrastructure

Similar to building the initial terraform can be completed with the command `terraform apply`

## Destroying the infrastucture

To destory the infrastructure you will need to ensure that the environment variables are set for the AWS KEY is setup.
```bash
terraform destroy
```

## Terraform

### VPC
I made use of an existing module `terraform-aws-modules/vpc/aws` to create the public and private subnets.

### Container
Used the nginx container with a basic html to display a basic html web page

### Load Balancer
The load balancer appects both http and https but redirects all http traffic to https to ensure that the host is making use of SSL

### Fargate service
built and configured to allow access to and from the load balancer with security permissions to access the ECR to pull images.