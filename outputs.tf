
output "ec2_public_ip" {
  value = aws_instance.bus_server.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.bus_db.endpoint
}
