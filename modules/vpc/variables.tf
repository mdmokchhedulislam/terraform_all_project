variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "cluster_name" {}
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "enable_dns_hostnames" { default = true }
