###############################################################################
# Cilium CNI — eBPF-based networking, security, and observability
#
# Design decisions:
#
#   1. kube-proxy replacement: Cilium replaces kube-proxy entirely, handling
#      service load balancing via eBPF in the kernel. This eliminates iptables
#      overhead and provides better performance and visibility.
#
#   2. ENI integration mode: On EKS, Cilium uses the AWS ENI IPAM mode to
#      allocate pod IPs directly from the VPC. Pods get VPC-routable IPs,
#      which is required for integration with AWS services (ALB, NLB, etc.).
#
#   3. Mutual TLS: Enabled via Cilium's built-in mTLS using SPIFFE workload
#      identities. Every pod gets a cryptographic identity — communication
#      is encrypted and authenticated at the kernel level without sidecars.
#
#   4. Hubble: Cilium's observability layer providing L3/L4/L7 flow logs,
#      DNS visibility, HTTP request/response metrics, and a service map UI.
#      This is the "continuous verification" component of zero trust.
#
#   5. Policy audit mode: Initially deploying policies in audit mode allows
#      observation before enforcement, reducing risk of breaking connectivity.
###############################################################################

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  # Wait for Cilium to be fully operational before Terraform considers
  # this resource complete. Critical because subsequent resources
  # (network policies, application deployments) depend on the CNI.
  wait    = true
  timeout = 600

  values = [yamlencode({
    # -------------------------------------------------------------------------
    # EKS Integration
    # -------------------------------------------------------------------------
    eni = {
      enabled = true
    }
    ipam = {
      mode = "eni"
    }
    egressMasqueradeInterfaces = "eth0"
    routingMode                = "native"

    # -------------------------------------------------------------------------
    # kube-proxy Replacement
    # eBPF-based service load balancing replaces iptables entirely
    # -------------------------------------------------------------------------
    kubeProxyReplacement = true

    # -------------------------------------------------------------------------
    # Mutual TLS — SPIFFE Workload Identity
    # Every pod receives a SPIFFE identity (spiffe://cluster/ns/<ns>/sa/<sa>)
    # All service-to-service traffic is encrypted and authenticated
    # -------------------------------------------------------------------------
    authentication = {
      mutual = {
        spiffe = {
          enabled = true
          install = {
            enabled = true
          }
        }
      }
    }

    encryption = {
      enabled = true
      type    = "wireguard"
    }

    # -------------------------------------------------------------------------
    # Hubble — Observability
    # L3/L4/L7 flow visibility, DNS monitoring, HTTP metrics
    # -------------------------------------------------------------------------
    hubble = {
      enabled = true
      relay = {
        enabled = true
      }
      ui = {
        enabled = true
      }
      metrics = {
        enabled = [
          "dns",
          "drop",
          "tcp",
          "flow",
          "icmp",
          "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction"
        ]
      }
    }

    # -------------------------------------------------------------------------
    # Operator Configuration
    # -------------------------------------------------------------------------
    operator = {
      replicas = 1
    }
  })]
}
