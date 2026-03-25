variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (us-east-1)"
  type        = string
  default     = "ami-0ec10929233384c7f"
}

variable "ssh_public_key" {
  description = "Your SSH public key content"
  type        = string
  sensitive   = true
}