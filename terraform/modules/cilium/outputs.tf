output "cilium_release_name" {
  description = "Name of the Cilium Helm release"
  value       = helm_release.cilium.name
}

output "cilium_namespace" {
  description = "Namespace where Cilium is installed"
  value       = helm_release.cilium.namespace
}

output "cilium_version" {
  description = "Version of Cilium deployed"
  value       = helm_release.cilium.version
}
