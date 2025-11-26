output "vpn_public_ip" {
  description = "Public IP for WireGuard VPN server"
  value       = aws_instance.vpn_ec2.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the VPN server"
  value       = "ssh -i ../vpn-key.pem ubuntu@${aws_instance.vpn_ec2.public_ip}"
}