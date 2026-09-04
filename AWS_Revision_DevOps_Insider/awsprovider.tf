terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"
    }
  }
}

provider "aws" {
    region = "ap-south-1"
}


resource "aws_instance" "test_instance_1" {
    ami = "ami-01a00762f46d584a1"
    #vpc_security_group_ids = ["vpc-0f125233ed055e2a1"]
    subnet_id = "subnet-0bcffbcfcedb7ff6f"
    instance_type = "t3.micro"
}

resource "aws_instance" "test_instance_2" {
    ami = "ami-01a00762f46d584a1"
    #vpc_security_group_ids = ["vpc-0f125233ed055e2a1"]
    subnet_id = "subnet-0bcffbcfcedb7ff6f"
    instance_type = "t3.micro"
}