output "autoscaling_group_id" {
  value = aws_autoscaling_group.Ec2InstanceAutoScalingGroup.name
}

output "Ec2InstanceLaunchTemplateSG_id" {
  value = aws_security_group.Ec2InstanceLaunchTemplateSG.id
}

output "Ec2InstanceLaunchTemplate_id" {
  value = aws_launch_template.Ec2InstanceLaunchTemplate.id
}

output "ALB_id" {
  value = aws_lb.ALB.id
}

output "ALB_DNS" {
  value = aws_lb.ALB.dns_name
}
