###############################################################################
# Zero Trust Kubernetes Architecture — Environment Configuration
###############################################################################

aws_region   = "eu-west-2"
project_name = "zero-trust-k8s"
environment  = "demo"

# Networking
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["eu-west-2a", "eu-west-2b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

# EKS
cluster_version     = "1.29"
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3
