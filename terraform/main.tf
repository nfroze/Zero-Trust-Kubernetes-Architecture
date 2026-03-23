###############################################################################
# VPC — Multi-AZ networking with public/private subnet separation
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

###############################################################################
# EKS — Managed Kubernetes with Cilium-compatible configuration
###############################################################################

module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

###############################################################################
# Cilium — eBPF-based CNI, service mesh, and network policy engine
#
# Replaces kube-proxy and the default AWS VPC CNI with Cilium for:
#   - mTLS via SPIFFE workload identity
#   - L3/L4/L7 network policy enforcement
#   - Hubble observability (flow logs, service map)
#   - eBPF dataplane (kernel-level packet processing, no sidecars)
###############################################################################

module "cilium" {
  source = "./modules/cilium"

  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint

  depends_on = [module.eks]
}
