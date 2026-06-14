variable "aws_region" {
  type        = string
  description = "AWS region for the EKS staging cluster."
  default     = "eu-west-3"
}

variable "aws_profile" {
  type        = string
  description = "Optional local AWS CLI profile. Leave empty in CI when using AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY."
  default     = ""
}

variable "project_name" {
  type        = string
  description = "Prefix for AWS resource names."
  default     = "todo-devsecops"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name. Defaults to <project_name>-eks."
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the staging VPC."
  default     = "10.42.0.0/16"
}

variable "node_instance_types" {
  type        = list(string)
  description = "Managed node group instance types. Keep small for staging costs."
  default     = ["t3.small"]
}

variable "node_capacity_type" {
  type        = string
  description = "EKS node capacity type: ON_DEMAND or SPOT."
  default     = "SPOT"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes."
  default     = 1
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes."
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes."
  default     = 2
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR repository used by the CI deployment stage."
  default     = "todo-app"
}
