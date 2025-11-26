# Secure WireGuard VPN on AWS with Terraform

A production-ready, secure, and cost-effective WireGuard VPN infrastructure fully automated with Terraform on AWS. This project demonstrates professional cloud engineering skills including infrastructure as code, networking, security, and automation.

## 🎯 Project Overview

This project implements a modern VPN solution using WireGuard deployed on AWS infrastructure. It showcases expertise in:

- **AWS Services**: VPC, EC2, Security Groups, Internet Gateway, Route Tables
- **Infrastructure as Code**: Terraform for complete automation
- **Cloud Security**: Minimal attack surface, encrypted tunnels, firewall rules
- **Linux Administration**: Ubuntu Server, iptables, systemd
- **Networking**: VPN protocols, NAT, IP forwarding, routing
- **DevOps**: Automated provisioning and client management scripts

## 🏗️ Architecture

![VPN Architecture Diagram](images/diagram,.jpg)

**Key Components:**
- VPC with public subnet
- EC2 instance running WireGuard
- Security Group allowing only UDP 51820
- Automated client provisioning
- NAT for internet routing

## 🚀 Technology Stack

| Component | Technology |
|-----------|-----------|
| Cloud Provider | AWS |
| IaC | Terraform 1.5+ |
| VPN Protocol | WireGuard |
| OS | Ubuntu 22.04 LTS (ARM64) |
| Instance Type | t4g.micro (ARM-based) |
| Automation | Bash scripts |
| Monitoring | CloudWatch (optional) |

## 📋 Prerequisites

- AWS account with appropriate permissions
- Terraform >= 1.5 installed
- AWS CLI configured
- SSH key pair for EC2 access

## 🚀 Quick Start

### 1. Create SSH Key Pair

```bash
aws ec2 create-key-pair --key-name vpn-key --query 'KeyMaterial' --output text > vpn-key.pem
chmod 400 vpn-key.pem
```

### 2. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Get Server Public IP

```bash
terraform output vpn_public_ip
```

### 4. Wait for Setup (2-3 minutes)

The user_data script automatically installs and configures WireGuard.

### 5. Generate Client Configuration

SSH into the server:
```bash
ssh -i ../vpn-key.pem ubuntu@<PUBLIC-IP>
```

Create a client:
```bash
sudo bash /opt/wireguard/scripts/create-client.sh client1
```

This automatically generates:
- Private/public key pair
- Client configuration file (`client1.conf`)
- QR code for mobile devices
- Registers client with the server

### 6. Download Client Config

```bash
scp -i vpn-key.pem ubuntu@<PUBLIC-IP>:/opt/wireguard/clients/client1.conf .
```

### 7. Connect

**Desktop:**
1. Install WireGuard client
2. Import `client1.conf`
3. Activate connection

**Mobile:**
1. Install WireGuard app
2. Scan QR code or import config
3. Connect

## 🔧 Configuration

### Variables

Edit `terraform/variables.tf`:

```hcl
variable "region" {
  default = "us-east-1"
}

variable "az" {
  default = "us-east-1a"
}

variable "ami_id" {
  default = "ami-0a105b59f5c9471cb"  # Ubuntu 22.04 ARM
}

variable "ssh_allowed_ip" {
  default = ""  # Leave empty to disable SSH
}

variable "key_name" {
  default = "vpn-key"
}
```

### Security Group Rules

- **UDP 51820**: WireGuard (open to 0.0.0.0/0)
- **TCP 22**: SSH (optional, restricted by IP)
- **Egress**: All traffic allowed

## 🛡️ Security Features

- **Minimal Attack Surface**: Only WireGuard port exposed
- **SSH Disabled by Default**: Optional IP-restricted access
- **Modern Cryptography**: WireGuard's state-of-the-art encryption
- **NAT with iptables**: Secure traffic forwarding
- **IP Forwarding**: Enabled only for wg0 interface
- **Key Rotation**: Easy client key regeneration

## 📊 Cost Estimation

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| t4g.micro instance | $0 - $6.13 (Free Tier eligible) |
| EBS Storage (8 GB) | ~$0.80 |
| Data Transfer (first 100 GB) | FREE |
| Data Transfer (after 100 GB) | $0.09/GB |

**Total**: 
- **Free Tier**: ~$1/month (storage only)
- **Without Free Tier**: ~$7-10/month (light usage)
- **Heavy usage (500 GB/month)**: ~$43/month

## 📝 Management Scripts

### `create-client.sh`

Automates client creation:
- Generates cryptographic keys
- Assigns incremental IP addresses (10.8.0.2, 10.8.0.3, etc.)
- Creates configuration file
- Displays QR code
- Registers peer with server

### `list-clients.sh`

Lists all connected clients and their status.

## 🔍 Monitoring

Optional CloudWatch integration for:
- Connection logs
- Bandwidth metrics
- Active client monitoring
- Security event tracking

## 🧪 Testing

Verify VPN connection:
```bash
# Check your public IP before connecting
curl ifconfig.me

# Connect to VPN, then check again
curl ifconfig.me  # Should show AWS region IP
```

## 📁 Project Structure

```
vpnFFE/
├── terraform/
│   ├── main.tf           # Main infrastructure
│   ├── variables.tf      # Input variables
│   └── outputs.tf        # Output values
├── scripts/
│   ├── create-client.sh  # Client provisioning
│   └── list-clients.sh   # Client management
├── architecture/
│   └── architecture-diagram.txt
└── README.md
```

## 🚧 Future Enhancements

- **Multi-Region Deployment**: VPN servers in US/EU/APAC
- **High Availability**: Auto Scaling Group with health checks
- **Monitoring Dashboard**: CloudWatch dashboards and alarms
- **CI/CD Pipeline**: GitHub Actions for automated deployments
- **Containerization**: Migrate to ECS/Fargate
- **DNS Management**: Route53 integration
- **Certificate Management**: Automated key rotation
- **Client Portal**: Web UI for self-service provisioning

## 🤝 Contributing

This is a portfolio project, but suggestions and improvements are welcome via issues or pull requests.

## 📄 License

MIT License - feel free to use this project for learning or production purposes.

## 👤 Author

Francisco Flores Enriquez  
Computer Systems Engineering Student

---

**Note**: This project is designed for educational and professional portfolio purposes. Always follow security best practices and compliance requirements for production deployments.


