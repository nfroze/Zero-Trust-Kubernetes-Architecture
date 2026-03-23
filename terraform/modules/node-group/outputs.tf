output "node_role_arn" {
  description = "ARN of the IAM role assigned to worker nodes"
  value       = aws_iam_role.nodes.arn
}

output "node_group_name" {
  description = "Name of the managed node group"
  value       = aws_eks_node_group.this.node_group_name
}
