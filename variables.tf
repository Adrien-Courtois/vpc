variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cidr_block" {
  type        = string
  description = "The CIDR Block use by the VPC"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC"
}

variable "azs" {
  type = map(any)
  default = {
    "a" = 0,
    "b" = 1,
    "c" = 2,

  }
  description = "List of AZS to the VPC"
}
