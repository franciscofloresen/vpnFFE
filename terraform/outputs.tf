output "vpn_public_ip" {
  description = "Public IP for WireGuard VPN server"
  value       = aws_instance.vpn_ec2.public_ip
}