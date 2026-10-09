resource "aws_imagebuilder_image_pipeline" "imgbuilder" {
  name                        = "${var.project_name}-${var.environment}-image-pipeline"
  description                 = "${var.project_name} ${var.environment} Image Pipeline"
  image_recipe_arn            = aws_imagebuilder_image_recipe.imgbuilder.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.imgbuilder.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.imgbuilder.arn
  status                      = "ENABLED"
  tags = {
    env = var.environment
  }
}

resource "aws_iam_role" "image_builder_role" {
  name = "${var.project_name}-${var.environment}-image-builder-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "CanLogToS3ImageBuilderLogs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "s3:PutObject"
        Resource = "*"
      }]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  ]
}

resource "aws_iam_instance_profile" "image_builder_instance_profile" {
  name = "${var.project_name}-${var.environment}-ImageBuilderInstanceProfile"
  role = aws_iam_role.image_builder_role.name
}

resource "aws_imagebuilder_infrastructure_configuration" "imgbuilder" {
  name                  = "${var.project_name}-instance-${var.environment}-image-builder-infrastructure-configuration"
  description           = "${var.project_name} ${var.environment} Configuration Settings"
  instance_profile_name = aws_iam_instance_profile.image_builder_instance_profile.name
  instance_types        = [var.instance_type]
  logging {
    s3_logs {
      s3_bucket_name = "${var.project_name}-${var.environment}-image-builder"
      s3_key_prefix  = "logs"
    }
  }
  resource_tags = {
    env = "build"
  }
  tags = {
    env = var.environment
  }
}

resource "aws_imagebuilder_distribution_configuration" "imgbuilder" {
  name        = "${var.project_name}-instance-${var.environment}-image-builder-distribution-configuration"
  description = "${var.project_name} ${var.environment} Distribution Settings"
  distribution {
    region = var.region
    ami_distribution_configuration {
      name = "${var.project_name}-${var.environment}-instance-ami - {{ imagebuilder:buildDate }}"
      ami_tags = {
        env = var.environment
      }
    }
    launch_template_configuration {
      launch_template_id      = var.ec2_launch_template
      default                 = true
      account_id = var.account_id
    }
  }
  tags = {
    env = var.environment
  }
}

resource "aws_imagebuilder_image_recipe" "imgbuilder" {
  name         = "${var.project_name}-${var.environment}-webserver-ami-recipe"
  parent_image = "arn:aws:imagebuilder:${var.region}:aws:image/ubuntu-server-24-lts-arm64/x.x.x"
  version      = "1.0.2"
  block_device_mapping {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = false
      volume_type           = "gp3"
      volume_size           = 20
    }
  }
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/amazon-cloudwatch-agent-linux/x.x.x"
  }
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/aws-codedeploy-agent-linux/x.x.x"
  }
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/aws-cli-version-2-linux/x.x.x"
  }
  component {
    component_arn = aws_imagebuilder_component.cloudwatch_component.arn
  }
  component {
    component_arn = aws_imagebuilder_component.dependencies_component.arn
  }
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/reboot-test-linux/x.x.x"
  }
  working_directory = "/tmp"
  tags = {
    env = "build"
  }
}

resource "aws_imagebuilder_component" "dependencies_component" {
  name                  = "${var.project_name} ${var.environment} Dependencies"
  description           = "${var.project_name} ${var.environment} Dependencies"
  platform              = "Linux"
  supported_os_versions = ["Ubuntu 16", "Ubuntu 18", "Ubuntu 20", "Ubuntu 24"]
  version               = "1.0.2" 
  data                  = <<DATA
name: PHP Build Component
description: Installs PHP
schemaVersion: 1.0

phases:
  - name: build
    steps:
    - name: AptUpdate
      action: ExecuteBash
      inputs:
        commands:
          - apt update
    - name: InstallApts
      action: ExecuteBash
      inputs:
        commands:
          - apt install -y freetype-dev libc-dev libjpeg-turbo-dev libpng-dev libzip-dev oniguruma-dev zlib-dev 
          - apt install -y libmagickwand-dev libmagickcore-dev
          - apt install -y supervisor
          - apt install mysql-client-core-8.0

    - name: InstallNginx
      action: ExecuteBash
      inputs:
        commands:
          - systemctl disable --now apache2
          - apt install -y nginx
          - systemctl start nginx.service

    - name: InstallPHP
      action: ExecuteBash
      inputs:
        commands:
          - apt install -y software-properties-common
          - add-apt-repository ppa:ondrej/php -y
          - echo -ne '\n' | enter
          - apt-get install php${var.php_version}-cli php${var.php_version}-dev php${var.php_version}-fpm php${var.php_version}-xml php${var.php_version}-mysqli php${var.php_version}-curl php${var.php_version}-mbstring php${var.php_version}-gd php${var.php_version}-zip php${var.php_version}-redis php${var.php_version}-intl php${var.php_version}-tokenizer php${var.php_version}-imagick -y --allow-unauthenticated
          - update-alternatives --set php /usr/bin/php${var.php_version} # force php and pear to current versionphp${var.php_version}-

    - name: ModifyPHP
      action: ExecuteBash
      inputs:
        commands:
          - sed -i 's/upload_max_filesize = .*/upload_max_filesize = '${var.upload_max_filesize}'/' /etc/php/${var.php_version}/fpm/php.ini
          - sed -i 's/post_max_size = .*/post_max_size = '${var.post_max_size}'/' /etc/php/${var.php_version}/fpm/php.ini
          - sed -i 's/pm = .*/pm = 'ondemand'/' /etc/php/${var.php_version}/fpm/pool.d/www.conf
          - sed -i 's/pm.max_children = .*/pm.max_children = '12'/' /etc/php/${var.php_version}/fpm/pool.d/www.conf
          - sed -i 's/pm.start_servers = .*/pm.start_servers = '8'/' /etc/php/${var.php_version}/fpm/pool.d/www.conf
          - sed -i 's/pm.min_spare_servers = .*/pm.min_spare_servers = '1'/' /etc/php/${var.php_version}/fpm/pool.d/www.conf
          - sed -i 's/pm.max_spare_servers = .*/pm.max_spare_servers = '8'/' /etc/php/${var.php_version}/fpm/pool.d/www.conf
          - sed -i 's/pm.process_idle_timeout = .*/pm.process_idle_timeout = '10s'/' /etc/php/${var.php_version}/fpm/pool.d/www.conf
          - systemctl restart nginx
          - systemctl restart php${var.php_version}-fpm

    - name: InstallNode
      action: ExecuteBash
      inputs:
        commands:
          - curl -s https://deb.nodesource.com/setup_${var.node_version}.x | sudo bash
          - apt install -y nodejs
          - npm install -g pm2
  - name: validate
    steps:
      - name: CheckPHPVersion
        action: ExecuteBash
        inputs:
          commands:
            - php -version
            - pecl version
      - name: CheckNginx
        action: ExecuteBash
        inputs:
          commands:
            - service nginx status
  - name: test
    steps:
      - name: TestUpAndRunning
        action: ExecuteBash
        inputs:
          commands:
            - curl http://localhost/
DATA
}

resource "aws_imagebuilder_component" "cloudwatch_component" {
  name                  = "${var.project_name} ${var.environment} Install Cloudwatch Agent Configuration on start"
  description           = "${var.project_name} Downloads the Cloudwatch SSM from Parameter Store"
  platform              = "Linux"
  supported_os_versions = ["Ubuntu 16", "Ubuntu 18", "Ubuntu 20", "Ubuntu 24"]
  version               = "1.0.2"
  data                  = <<DATA
name: InstallCloudwatchConfiguration
description: This installs a startup script that pulls cloudwatch configuration from SSM on reboot
schemaVersion: 1.0

parameters:
  - ParameterName:
      type: string
      default: "AmazonCloudWatch-asginstance-configuration-ssm-${var.environment}"
      description: Cloudwatch Configuration SSM Parameter Name

phases:
  - name: build
    steps:
      - name: CreateServiceFile
        action: ExecuteBash
        inputs:
          commands:
          - "echo \"[Unit]

Description=Configures Cloudwatch Agent

After=network.target

[Service]

ExecStart=/bin/bash -c '/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:{{ ParameterName }} && /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a start'

[Install]

WantedBy=multi-user.target
\" > /etc/systemd/system/configure-cwagent.service"
      - name: EnableServiceOnRestart
        action: ExecuteBash
        inputs: 
          commands:
            - cat /etc/systemd/system/configure-cwagent.service
            - systemctl enable configure-cwagent
DATA
}

resource "aws_s3_bucket" "image_builder_bucket" {
    bucket = "${var.project_name}-${var.environment}-image-builder"
    tags = {
        env = "build"
    }
}

resource "aws_s3_bucket_versioning" "image_builder_bucket_versioning" {
    bucket = aws_s3_bucket.image_builder_bucket.id
  
    versioning_configuration {
        status = "Enabled"
    }
}