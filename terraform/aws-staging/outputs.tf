output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "aws_region" {
  value = var.aws_region
}

output "kubectl_update_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}
