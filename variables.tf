variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "ap-southeast-1" # Singapore — closest to Sri Lanka
}

variable "project_name" {
  description = "Short project name used as a prefix for all resources"
  type        = string
  default     = "genepay"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "demo"
}

variable "instance_type" {
  description = <<-EOT
    EC2 instance type for the K3s single-node cluster.
    Recommended:
      t3.large  (2 vCPU / 8 GB)  — comfortable for the demo stack
      t3.xlarge (4 vCPU / 16 GB) — use if biometric/face-recognition load is heavy
  EOT
  type    = string
  default = "t3.large"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair to use for SSH access"
  type        = string
  # No default — must be provided by the user
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH and reach the K3s API (port 6443). Restrict to your IP!"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Tighten this before use: e.g. ["203.0.113.5/32"]
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB. 30 GB is enough for pulled images + K3s state."
  type        = number
  default     = 30
}
