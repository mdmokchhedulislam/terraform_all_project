
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
