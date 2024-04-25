output "IP_of_Public_EC2" {
  description = "Contains the Public IP address"
  value       = aws_instance.Public_EC2.public_ip
}

output "file_content" {
  value     = tls_private_key.key_pair.private_key_pem
  sensitive = true
}