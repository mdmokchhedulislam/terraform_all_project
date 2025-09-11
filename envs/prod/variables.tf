variable "cluster_name" { default = "prod-eks" }
variable "vpc_cidr" { default = "10.1.0.0/16" }
variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}
variable "public_subnet_cidrs" {
  default = ["10.1.0.0/24", "10.1.1.0/24"]
}
variable "private_subnet_cidrs" {
  default = ["10.1.10.0/24", "10.1.11.0/24"]
}
