



module "vpc" {
  source = "../../modules/vpc"
  cluster_name = var.cluster_name
  vpc_cidr = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones = var.availability_zones


}
