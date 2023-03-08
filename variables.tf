variable "aws_region" {
  type    = string
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
  description = "List of AZS to the VPC"
}
