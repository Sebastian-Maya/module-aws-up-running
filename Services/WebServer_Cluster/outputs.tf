output "alb_dns_name" {
  description = "Domain Name of the load balancer"
  value       = aws_lb.lb-servers.dns_name
}

output "public_ip" {
  value       = aws_launch_template.web-server-1.id #aws_launch_template.web-server-1.associate_public_ip_address
  description = "ip of the web_server"
}

output "asg_name" {
  value       = aws_autoscaling_group.asg-web-server-1.name
  description = "The name of the auto-scaling group"
}

output "alb_security_group_id" {
  value       = aws_security_group.lb-nsg.id
  description = "The ID of the Security Group attached to the load balancer"
}
