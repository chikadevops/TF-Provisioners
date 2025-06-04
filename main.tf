provider "aws" {
  region = "us-east-1"
}

variable "cidr" {
  default = "10.0.0.0/16"
}

# resource "aws_key_pair" "example" {
#   key_name   = "test-key"
#   public_key = file("/home/haelz/.ssh/id_rsa")
# }

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name   = "webSg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "webSg"
  }
}

resource "aws_instance" "server" {
  ami                    = "ami-0261755bbcb8c4a84" #"ami-084568db4383264d4"
  instance_type          = "t2.micro"
  key_name               = "MyEC2Key" #aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id

  tags = {
    Name = "MyWebServer"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/home/haelz/MyEC2Key.pem")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "app.py"
    destination = "/home/ubuntu/app.py"
  }

  provisioner "remote-exec" {
    inline = [ #This inline block worked but only with ubuntu 20
      "sudo apt update -y",
      "sudo apt-get install -y python3-pip",
      "cd /home/ubuntu",
      "sudo pip3 install flask",
      "sudo python3 app.py"

      #   "echo 'Hello from remote server!'",
      #   "sudo apt update -y",
      #   "sudo apt install -y python3-pip python3.12-venv",
      #   "cd /home/ubuntu",
      #   "python3 -m venv venv",
      #   "venv/bin/pip install --upgrade pip",
      #   "venv/bin/pip install flask",
      #   "sudo nohup venv/bin/python app.py > app.log 2>&1 &" # This works but i had to ssh into the instance and run it
    ]
  }
}
