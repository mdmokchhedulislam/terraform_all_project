
resource "aws_vpc" "main" {

cidr_block = "10.0.0.0/16"

  tags = {
    Name ="myvpc" 
  }
}


resource "aws_subnet" "public1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"

    tags = {
      Name =  "public_subnet1"
    }
  
}

resource "aws_internet_gateway" "my_internet_gatway" {
    vpc_id = aws_vpc.main.id
  
}

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_internet_gatway.id
    }
  
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_route_table.id
}


resource "aws_security_group" "ec2_security_group" {
  name   = "ec2_security_group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "my-key"
  public_key = file("C:/Users/mokch/.ssh/id_rsa.pub")  # Windows user
}


resource "aws_instance" "ec2_instance" {
  ami                    = "ami-0c94855ba95c71c99"  # Amazon Linux 2 in us-east-1 (update as needed)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = aws_key_pair.ec2_key_pair.key_name
  associate_public_ip_address = true

    tags = {
    Name = "terraform-ec2"
  }
}

