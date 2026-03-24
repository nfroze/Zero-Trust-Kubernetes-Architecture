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

  project_name       = var.project_name
  environment        = var.environment
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
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

###############################################################################
# Node Group — Created AFTER Cilium is installed
#
# This ordering solves the CNI chicken-and-egg problem on EKS:
#   1. EKS cluster is created (API server only, no nodes)
#   2. Cilium is installed via Helm (CNI is now available)
#   3. Node group is created (nodes register, Cilium assigns pod IPs,
#      kubelet marks nodes Ready)
#
# Without this ordering, nodes start without a CNI, kubelet cannot
# configure networking, and the node group health check fails.
###############################################################################

module "node_group" {
  source = "./modules/node-group"

  project_name        = var.project_name
  cluster_name        = module.eks.cluster_name
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  depends_on = [module.cilium]
}

###############################################################################
# CoreDNS — EKS Managed Addon
#
# Created AFTER the node group so CoreDNS pods have nodes to schedule on.
# bootstrap_self_managed_addons = false disables all default addons including
# CoreDNS. Without it, pods cannot resolve service names.
###############################################################################

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [module.node_group]
}
