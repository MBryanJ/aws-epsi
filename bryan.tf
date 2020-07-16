provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "20.0.1.0/24"

  tags = {
    Name = "public-a-tf"
  }
}

resource "aws_subnet" "public-b" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "20.0.2.0/24"

  tags = {
    Name = "public-b-tf"
  }
}

resource "aws_vpc" "default" {
  cidr_block = "20.0.0.0/16"
  
  tags = {
    Name = "terraform"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "igw-tf"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "internet-tf"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public-b.id
  route_table_id = aws_route_table.r.id
}


resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "ec2-key-tf"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_security_group" "allow_http" {
  name        = "allow_tls"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "allow_http-tf"
  }
}

resource "aws_lb" "alb_terraform" {
  name               = "alb-terraform"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.allow_http.id}"]
  subnets            = ["${aws_subnet.public-a.id},${aws_subnet.public-b.id}"]
}

resource "aws_lb_target_group" "target_group_tf" {
  name     = "target-group-tf"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}



data "aws_autoscaling_group" "autogroup" {
  name = "autogroup"
}

resource "aws_autoscaling_policy" "bat" {
  name                   = "foobar3-terraform-test"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.bar.name}"
}

resource "aws_autoscaling_group" "bar" {
  availability_zones        = ["us-east-1a"]
  name                      = "foobar3-terraform-test"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  placement_group           = aws_placement_group.asg_placement_group_terraform.id
  launch_configuration      = aws_launch_configuration.launch_configuration_terraform.name
  vpc_zone_identifier       = aws_subnet.subnet_1_terraform.id


}
  initial_lifecycle_hook {
    name                 = "asg_lifecycle_terraform"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 2000
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }



  timeouts {
    delete = "5m"
  }
}

output "private_key" {
  value = tls_private_key.key_terraform.private_key_pem
}
