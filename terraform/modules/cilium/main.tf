###############################################################################
# Cilium CNI — eBPF-based networking, security, and observability
#
# Design decisions:
#
#   1. kube-proxy replacement: Cilium replaces kube-proxy entirely, handling
#      service load balancing via eBPF in the kernel. This eliminates iptables
#      overhead and provides better performance and visibility.
#
#   2. Overlay mode with VXLAN tunnelling: Pods receive Cilium-managed IPs
#      from the cluster CIDR and traffic is encapsulated between nodes.
#      This provides full compatibility with Cilium's kube-proxy replacement
#      and avoids the ENI mode limitations on EKS where pod traffic bypasses
#      the node's network stack, breaking ClusterIP service routing.
#
#   3. Mutual TLS: Enabled via Cilium's built-in mTLS using SPIFFE workload
#      identities. Every pod gets a cryptographic identity — communication
#      is encrypted and authenticated at the kernel level without sidecars.
#
#   4. Hubble: Cilium's observability layer providing L3/L4/L7 flow logs,
#      DNS visibility, HTTP request/response metrics, and a service map UI.
#      This is the "continuous verification" component of zero trust.
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
    # EKS Overlay Mode
    # Pods get Cilium-managed IPs from the cluster CIDR (10.244.0.0/16).
    # Traffic between nodes is encapsulated via VXLAN. This gives Cilium full
    # control over the datapath including service routing and policy enforcement.
    # -------------------------------------------------------------------------
    ipam = {
      mode = "cluster-pool"
      operator = {
        clusterPoolIPv4PodCIDRList = ["10.244.0.0/16"]
        clusterPoolIPv4MaskSize    = 24
      }
    }
    routingMode    = "tunnel"
    tunnelProtocol = "vxlan"

    # -------------------------------------------------------------------------
    # kube-proxy Replacement
    # eBPF-based service load balancing replaces iptables entirely.
    # In overlay mode, Cilium has full visibility and control over all traffic
    # including ClusterIP services — no iptables bypass issues.
    # -------------------------------------------------------------------------
    kubeProxyReplacement = true

    # Direct API server connection — Cilium connects to the EKS API endpoint
    # directly, bypassing the kubernetes ClusterIP which requires kube-proxy
    # (or Cilium itself) to be operational first.
    k8sServiceHost = replace(var.cluster_endpoint, "https://", "")
    k8sServicePort = "443"

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
