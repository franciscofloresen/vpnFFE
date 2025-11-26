variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "az" {
  description = "Availability zone for subnet"
  default     = "us-east-1a"
}

variable "ami_id" {
  description = "Ubuntu ARM AMI (t4g.micro compatible)"
  default     = "ami-0a105b59f5c9471cb" # Ubuntu 22.04 ARM us-east-1
}

variable "ssh_allowed_ip" {
  description = "IP allowed for SSH (CIDR). If empty, SSH is disabled."
  default     = ""
}

variable "key_name" {
  description = "SSH key pair name for EC2 access"
  default     = "vpn-key"
}