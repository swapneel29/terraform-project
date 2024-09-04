

resource "aws_internet_gateway" "my-igw" {
     vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "my-route-table" {
      vpc_id = aws_vpc.my_vpc.id
      route  {
        cidr_block="0.0.0.0/0"
        gateway_id= aws_internet_gateway.my-igw.id
      }
}

resource "aws_route_table_association" "rta1" {
        subnet_id = aws_subnet.subnet-01.id
        route_table_id = aws_route_table.my-route-table.id
}

resource "aws_route_table_association" "rta2" {
        subnet_id = aws_subnet.subnet-02.id
        route_table_id = aws_route_table.my-route-table.id
}

resource "aws_security_group" "sg01" {
  name        = "webserver-sg"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "webserver-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.sg01.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.sg01.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.sg01.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_s3_bucket" "bkt01" {
       bucket = "my-terraform-28-2024-bucket"
        tags = {
            Name        = "My bucket"
            Environment = "Dev"
  }
}

resource "aws_instance" "ec201" {
  ami = var.ami_id
  instance_type = var.instance_type
  security_groups = [aws_security_group.sg01.id]
  subnet_id = aws_subnet.subnet-01.id
  associate_public_ip_address = true
  user_data = base64encode(file("userdata.sh"))
  tags={
    Name="terraform-instance-1"
  }
}
resource "aws_instance" "ec202" {
  ami = var.ami_id
  instance_type = var.instance_type
  security_groups = [aws_security_group.sg01.id]
  subnet_id = aws_subnet.subnet-02.id
  associate_public_ip_address = true
  user_data = base64encode(file("userdata1.sh"))
  tags={
    Name="terraform-instance-2"
  }
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg01.id]
  subnets            = [aws_subnet.subnet-01.id,aws_subnet.subnet-02.id]

  enable_deletion_protection = true
  tags = {
    Name = "terraform-alb"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "test1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.ec201.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.ec202.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.test.arn   
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.test.dns_name
}

