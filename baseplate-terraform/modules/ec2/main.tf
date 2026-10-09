resource "aws_security_group" "ALBSG" {
  name        = "${var.environment}-pub-01-alb"
  description = "Security Group for Application Load Balancer to expose HTTP 80"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

resource "aws_lb" "ALB" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALBSG.id]
  subnets            = [var.public_subnet_1_id, var.public_subnet_2_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

resource "aws_lb_listener" "ALBListener" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ALBTG.arn
  }

  lifecycle {
    ignore_changes = [
      default_action[0].target_group_arn,
      default_action[0].type,
      default_action[0].redirect,
    ]
  }
}

resource "aws_lb_target_group" "ALBTG" {
  name        = "${var.project_name}-${var.environment}-asg-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-asg-tg"
  }
}

resource "aws_security_group" "Ec2InstanceLaunchTemplateSG" {
  name        = "${var.environment}-pub-01-instances"
  description = "Security Group for Launchtemplate"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ALBSG.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ALBSG.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["13.239.158.0/29"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-pub-01-instances"
    env  = "${var.environment}"
  }
}

resource "aws_launch_template" "Ec2InstanceLaunchTemplate" {
  name = "${var.project_name}-${var.environment}-asg-instance-launch-template"

  iam_instance_profile {
    arn = aws_iam_instance_profile.MyIamInstanceProfile.arn
  }

  instance_type = var.instance_type
  image_id      = var.image_id

  monitoring {
    enabled = true
  }

  network_interfaces {
    security_groups = [aws_security_group.Ec2InstanceLaunchTemplateSG.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      env       = "${var.environment}"
      autoscale = "true"
      Name      = "${var.project_name}-ec2-${var.environment}-appsrv-asginstance"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      env       = "${var.environment}"
      autoscale = "true"
    }
  }

  user_data = base64encode(<<-EOT
    #cloud-config
    swap:
      filename: /swapfile
      size: "2G"
      maxsize: "2G"
      swappiness: 10
      vm.overcommit_memory: auto
  EOT
  )

  lifecycle {
    ignore_changes = [
      latest_version,
      description,
      image_id,
      tags,
      tags_all
    ]
  }
}


resource "aws_autoscaling_group" "Ec2InstanceAutoScalingGroup" {
  name                 = "${var.project_name}-${var.environment}-asg"
  desired_capacity     = var.ec2_auto_scale_desired_capacity
  max_size             = var.ec2_auto_scale_max_size
  min_size             = var.ec2_auto_scale_min_size
  vpc_zone_identifier  = [var.public_subnet_1_id, var.public_subnet_2_id]
  target_group_arns    = [aws_lb_target_group.ALBTG.arn]

  launch_template {
    id      = aws_launch_template.Ec2InstanceLaunchTemplate.id
    version = "$Latest"
  }

  tag {
    key                 = "autoscaling"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
      max_size,
      min_size,
      vpc_zone_identifier,
      target_group_arns,
      launch_template,
      tag,
    ]
  }
}

resource "aws_autoscaling_policy" "CPUTracking" {
  name                   = "${var.environment}-CPUTrackingPolicy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.Ec2InstanceAutoScalingGroup.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

resource "aws_autoscaling_policy" "ScaleUpPolicy" {
  name                   = "${var.environment}-ScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 1
  autoscaling_group_name = aws_autoscaling_group.Ec2InstanceAutoScalingGroup.name
}

resource "aws_autoscaling_policy" "ScaleDownPolicy" {
  name                   = "${var.environment}-ScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.Ec2InstanceAutoScalingGroup.name
}

resource "aws_cloudwatch_metric_alarm" "MemoryAlarmHigh" {
  alarm_name          = "${var.environment}-MemoryAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.Ec2InstanceAutoScalingGroup.name
  }

  alarm_actions = [aws_autoscaling_policy.ScaleUpPolicy.arn]
}

resource "aws_cloudwatch_metric_alarm" "MemoryAlarmLow" {
  alarm_name          = "${var.environment}-MemoryAlarmLow"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.Ec2InstanceAutoScalingGroup.name
  }

  alarm_actions = [aws_autoscaling_policy.ScaleDownPolicy.arn]
}

resource "aws_iam_instance_profile" "MyIamInstanceProfile" {
  name = "${var.project_name}-${var.environment}-web-instance-role-instance-profile"
  path = "/"

  role = aws_iam_role.WebInstanceRole.name
}

resource "aws_iam_role" "WebInstanceRole" {
  name = "${var.project_name}-${var.environment}-web-instance-role"

  inline_policy {
    name = "SESFullAccessPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ses:*"
          ]
          Resource = "*"
        }
      ]
    })
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "S3AccessPolicies"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*"
          ]
          Resource = [
            "*",
            "arn:aws:s3:::aws-codedeploy-ap-southeast-2/*",
            "arn:aws:s3:::aws-codedeploy-us-east-2/*",
            "arn:aws:s3:::aws-codedeploy-us-east-1/*",
            "arn:aws:s3:::aws-codedeploy-us-west-1/*",
            "arn:aws:s3:::aws-codedeploy-us-west-2/*",
            "arn:aws:s3:::aws-codedeploy-ca-central-1/*",
            "arn:aws:s3:::aws-codedeploy-eu-west-1/*",
            "arn:aws:s3:::aws-codedeploy-eu-west-2/*",
            "arn:aws:s3:::aws-codedeploy-eu-west-3/*",
            "arn:aws:s3:::aws-codedeploy-eu-central-1/*",
            "arn:aws:s3:::aws-codedeploy-ap-east-1/*",
            "arn:aws:s3:::aws-codedeploy-ap-northeast-1/*",
            "arn:aws:s3:::aws-codedeploy-ap-northeast-2/*",
            "arn:aws:s3:::aws-codedeploy-ap-southeast-1/*",
            "arn:aws:s3:::aws-codedeploy-ap-south-1/*",
            "arn:aws:s3:::aws-codedeploy-sa-east-1/*"
          ]
        }
      ]
    })
  }

  inline_policy {
    name = "AssetsS3AccessPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*",
            "s3:Put*"
          ]
          Resource = "*"
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeployLimited",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_s3_bucket" "ProjBucket" {
  bucket = "${var.project_name}-${var.environment}"

  tags = {
    env = "${var.environment}"
  }
}

resource "aws_ssm_parameter" "AmazonCloudWatchParameter" {
  name        = "AmazonCloudWatch-asginstance-configuration-ssm-${var.environment}"
  description = "Cloudwatch Configuration for all ASG instances"
  type        = "String"
  value       = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/nginx/api${var.environment}/access.log"
              log_group_name  = "api${var.environment}/access.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/api${var.environment}/error.log"
              log_group_name  = "api${var.environment}/error.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/www/api/storage/logs/*.log"
              log_group_name  = "api${var.environment}/logs"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/cms${var.environment}/access.log"
              log_group_name  = "cms${var.environment}/access.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/cms${var.environment}/error.log"
              log_group_name  = "cms${var.environment}/error.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/web${var.environment}/access.log"
              log_group_name  = "web${var.environment}/access.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/web${var.environment}/error.log"
              log_group_name  = "web${var.environment}/error.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/access.log"
              log_group_name  = "nginx/access.log"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/error.log"
              log_group_name  = "nginx/error.log"
              log_stream_name = "{instance_id}"
            }
          ]
        }
      }
    }
    metrics = {
      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
        ImageId              = "$${aws:ImageId}"
        InstanceId           = "$${aws:InstanceId}"
        InstanceType         = "$${aws:InstanceType}"
      }
      aggregation_dimensions = [
        ["InstanceId"],
        ["AutoScalingGroupName"],
        ["AutoScalingGroupName", "InstanceType"]
      ]
      metrics_collected = {
        disk = {
          measurement                = ["used_percent"]
          metrics_collection_interval = 60
          resources                  = ["*"]
        }
        mem = {
          measurement                = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
        statsd = {
          metrics_aggregation_interval = 60
          metrics_collection_interval  = 10
          service_address              = ":8125"
        }
      }
    }
  })
}

resource "aws_iam_role" "VpcFlowRole" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "flowlogs-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ]
          Resource = aws_cloudwatch_log_group.VpcLogGroup.arn
        }
      ]
    })
  }
}

resource "aws_cloudwatch_log_group" "VpcLogGroup" {
  retention_in_days = 60
}

resource "aws_flow_log" "FlowLog" {
  log_destination      = aws_cloudwatch_log_group.VpcLogGroup.arn
  iam_role_arn         = aws_iam_role.VpcFlowRole.arn
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"

  tags = {
    Name = "${var.project_name}-vpcflowlog-${var.environment}"
  }
}