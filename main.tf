mkdir vpc
main.tf

resource "aws_vpc" "tier_vpc" {
  cidr_block  = var.vpc_cidr

  tags = {
    Name = "tier-vpc"main.tf 

  }
}

resource "aws_subnet" "subnet_one" {
  vpc_id     = aws_vpc.tier_vpc.id
  cidr_block = var.sub_one_cidr
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-one"
  }
}

resource "aws_subnet" "subnet_two" {
  vpc_id     = aws_vpc.tier_vpc.id
  cidr_block = var.sub_two_cidr
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-two"
  }
}

resource "aws_subnet" "subnet_three" {
  vpc_id     = aws_vpc.tier_vpc.id
  cidr_block = var.sub_three_cidr
  availability_zone = "us-east-1c"

  tags = {
    Name = "subnet-three"
 }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.tier_vpc.id

  tags = {
    Name = "gateway"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.tier_vpc.id

  route {
    cidr_block = var.route_cidr
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "route-table"
  }
}

resource "aws_route_table_association" "first_asso" {
  subnet_id      = aws_subnet.subnet_one.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "second_asso" {
  subnet_id      = aws_subnet.subnet_two.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "third_asso" {
  subnet_id      = aws_subnet.subnet_three.id
  route_table_id = aws_route_table.route_table.id
}

(vpc)
variable.tf 

variable "vpc_cidr" {}
variable "sub_one_cidr" {}
variable "sub_two_cidr" {}
variable "sub_three_cidr" {}
variable "route_cidr" {}


(vpc) 
output.tf

output "vpc_output" {
  value = aws_vpc.tier_vpc.id

}

output "sub1_output" {
  value = aws_subnet.subnet_one.id

}

output "sub2_output" {
  value = aws_subnet.subnet_two.id

}

output "sub3_output" {
  value = aws_subnet.subnet_three.id

}

mkdir sg 
(sg)
main.tf 
resource "aws_security_group" "security" {
  name   = "security"
  vpc_id = var.vpc_id

  tags = {
    Name = "security"
  }

  ingress {
   from_port = 22
   to_port = 22
   protocol = "TCP"
   cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
   from_port = 80
   to_port = 80
   protocol = "TCP"
   cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
   from_port = 8080
   to_port = 8080
   protocol = "TCP"
   cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
   from_port = 3306
   to_port = 3306
   protocol = "TCP"
   cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

(sg)
variable.tf
variable "vpc_id" 

 (sg) output "security_output" {
  value = aws_security_group.security.id
}

mkdir rds 
(rds) main.tf
resource "aws_db_subnet_group" "db_sub_group" {
  subnet_ids = var.sub_ids

tags = {
  Name = "db-sub-group"
}
}


resource "aws_db_instance" "database_rds" {
allocated_storage    = 20
db_name              = "databaserds"
engine               = "mysql"
engine_version       = "8.0"
instance_class       = "db.t3.micro"
username             = "mayuri"
password             = "12345678"
db_subnet_group_name = aws_db_subnet_group.db_sub_group.name
port                 = 3306
skip_final_snapshot  = true
vpc_security_group_ids = var.sg_id
}

 (rds) variable.tf
variable "sg_id" {}
variable "sub_ids" {}

(rds) output.tf

output "sub_group_output" {
  value = aws_db_subnet_group.db_sub_group.name
}

output "rds_output" {
  value = aws_db_instance.database_rds.address
}

mkdir backend 

main.tf 

data "template_file" "first_template" {
  template = file("context.tpl")

  vars = {
     ENDPOINT = var.db_endpoint
  }
}



resource "aws_instance" "backend_instance" {
  ami = var.image_id
  instance_type = var.i_type
  key_name = var.key_pair
  vpc_security_group_ids = var.sg_back
  subnet_id = var.back_sub

  connection {
   type = "ssh"
   user = "ec2-user"
   host = self.public_ip
   private_key = file("./key_east.pem")
 }

 provisioner "remote-exec" {
   inline = [
     "sudo yum update -y",
     "sudo yum install java-21-amazon-corretto-1:21.0.6+7-1.amzn2023.1.x86_64 -y",
     "sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.102/bin/apache-tomcat-9.0.102.tar.gz",
     "sudo tar -xvzf apache-tomcat-9.0.102.tar.gz -C /opt",
     "sudo chmod +x /opt/apache-tomcat-9.0.102/bin/catalina.sh"
    ]
  }

 provisioner "file" {
  content     = data.template_file.first_template.rendered
  destination = "/tmp/context.xml"
}

provisioner "remote-exec" {
  inline = [
    "sudo mv /tmp/context.xml /opt/apache-tomcat-9.0.102/conf/context.xml"
  ]
}

 provisioner "file" {
   source = "./student.war"
   destination = "/tmp/student.war"
 }
 provisioner "remote-exec" {
  inline = [
    "sudo mv /tmp/student.war /opt/apache-tomcat-9.0.102/webapps/student.war"
  ]
}
 provisioner "file" {
   source = "./mysql-connector.jar"
   destination = "/tmp/mysql-connector.jar"
 }

 provisioner "remote-exec" {
  inline = [
    "sudo mv /tmp/mysql-connector.jar /opt/apache-tomcat-9.0.102/lib/mysql-connector.jar"
  ]
}

 provisioner "file" {
  source = "./student.sql"
  destination = "/tmp/student.sql"
 }
 provisioner "remote-exec" {
  inline = [
     "sudo yum install mariadb* -y",
     "sudo mysql -h ${var.db_endpoint} -u mayuri -p12345678 databaserds < /tmp/student.sql"
  ]
 }
 provisioner "remote-exec" {
  inline = [
     "sudo /opt/apache-tomcat-9.0.102/bin/catalina.sh start"
  ]
 }
}

(backend) variable.tf

variable "image_id" {}
variable "i_type" {}
variable "key_pair" {}
variable "sg_back" {}
variable "db_endpoint" {}
variable "back_sub" {}


(backend) output.tf

output "backend_output" {
  value = aws_instance.backend_instance.public_ip
}

mkdir frontend 

main.tf 
data "template_file" "index_template" {
  template = file("index.tpl")

  vars = {
     backend_ip = var.ip_backend
  }
}

resource "aws_instance" "frontend_instance" {
  ami = var.image_id
  instance_type = var.i_type
  key_name = var.key_pair
  vpc_security_group_ids = var.sg_front
  subnet_id = var.front_sub

  connection {
   type = "ssh"
   user = "ec2-user"
   host = self.public_ip
   private_key = file("./key_east.pem")
 }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install nginx -y",
      "sudo systemctl start nginx",
      "sudo systemctl enable nginx"
    ]
  }

  provisioner "file" {
  content     = data.template_file.index_template.rendered
  destination = "/tmp/index.html"
}

 provisioner "remote-exec" {
  inline = [
    "sudo mv /tmp/index.html /usr/share/nginx/html/index.html",
    "sudo systemctl restart nginx"
  ]
}

}

(fronend) variable.tf 

variable "image_id" {}
variable "i_type" {}
variable "key_pair" {}
variable "sg_front" {}
variable "ip_backend" {}
variable "front_sub" {}

(frontend) output.tf

output "frontend_output" {
  value = aws_instance.frontend_instance.public_ip
}


mkdir r53 
main.tf
resource "aws_route53_zone" "hosted_zone" {
  name = "berojgar.site"
}

resource "aws_route53_record" "record_aws" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "berojgar.site"
  type    = "A"
  ttl     = 300
  records = [var.frontend_public_ip]
}

(r53) variable.tf

variable "frontend_public_ip" {}

/root
main.tf  

module "module_vpc" {
  source = "/root/vpc"
  vpc_cidr           = "16.0.0.0/16"
  sub_one_cidr       = "16.0.0.0/24"
  sub_two_cidr       = "16.0.1.0/25"
  sub_three_cidr     = "16.0.1.128/26"
  route_cidr         =  "0.0.0.0/0"
}

module "module_sg" {
  source = "/root/sg"
  vpc_id = module.module_vpc.vpc_output

  }

module "module_rds" {
  source = "/root/rds"
  sg_id  = [module.module_sg.security_output]
  sub_ids = [module.module_vpc.sub1_output, module.module_vpc.sub2_output, module.module_vpc.sub3_output]
  }

module "module_back" {
  source = "/root/back"
  image_id           = "ami-071226ecf16aa7d96"
  i_type             = "t2.micro"
  key_pair           = "key_east"
  sg_back            = [module.module_sg.security_output]
  back_sub           = module.module_vpc.sub1_output
  db_endpoint        = module.module_rds.rds_output


}

module "module_front" {
  source = "/root/front"
  image_id          = "ami-071226ecf16aa7d96"
  i_type             = "t2.micro"
  key_pair          = "key_east"
  sg_front           = [module.module_sg.security_output]
  front_sub          = module.module_vpc.sub1_output
  ip_backend         = module.module_back.backend_output

}

module "module_route53" {
  source = "/root/route"
  frontend_public_ip = module.module_front.frontend_output
