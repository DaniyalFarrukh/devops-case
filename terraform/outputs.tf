output "server_public_ip" {
  description = "Public IP of the EC2 instance (use this to SSH and access the app)"
  value       = aws_eip.mern_eip.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.mern_eip.public_ip}"
}

output "app_url" {
  description = "URL to access the frontend"
  value       = "http://${aws_eip.mern_eip.public_ip}"
}

output "api_url" {
  description = "URL to access the backend API"
  value       = "http://${aws_eip.mern_eip.public_ip}:5050"
}
