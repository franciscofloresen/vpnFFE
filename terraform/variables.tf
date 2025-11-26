variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "az" {
  description = "Availability zone for subnet"
  default     = "us-east-1a"
}

variable "ami_id" {
  description = "Ubuntu ARM AMI (t4g.micro compatible). Leave empty to auto-detect latest Ubuntu 22.04 ARM."
  default     = ""
}

variable "ssh_allowed_ip" {
  description = "IP allowed for SSH (CIDR). If empty, SSH is disabled."
  default     = ""

  validation {
    condition     = var.ssh_allowed_ip == "" || can(cidrhost(var.ssh_allowed_ip, 0))
    error_message = "ssh_allowed_ip must be a valid CIDR block (e.g., 203.0.113.0/32)"
  }
}

variable "key_name" {
  description = "SSH key pair name for EC2 access"
  default     = "vpn-key"
}