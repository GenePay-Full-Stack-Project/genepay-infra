output "instance_id" {
  description = "EC2 instance ID of the K3s node"
  value       = aws_instance.genepay_node.id
}

output "public_ip" {
  description = "Elastic (static) public IP — use this for DNS and kubectl config"
  value       = aws_eip.genepay_eip.public_ip
}

output "public_dns" {
  description = "Public DNS hostname of the instance"
  value       = aws_instance.genepay_node.public_dns
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.genepay_eip.public_ip}"
}

output "ecr_repository_urls" {
  description = "Map of service name → ECR repository URL"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "kubeconfig_fetch_command" {
  description = "Command to copy K3s kubeconfig from the instance after bootstrap"
  value       = "scp -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.genepay_eip.public_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/genepay-k3s.yaml && sed -i 's/127.0.0.1/${aws_eip.genepay_eip.public_ip}/g' ~/.kube/genepay-k3s.yaml"
}
