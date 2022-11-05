module "aws-job-code" {
  source              = "../../modules/aws/jobs-code"
  data_files          = var.data_files
  pysequila_version   = var.pysequila_version
  sequila_version     = var.sequila_version
  pysequila_image_eks = var.pysequila_image_eks
}

resource "aws_ecr_repository" "ecr" {
  count                = (var.aws-emr-deploy || var.aws-eks-deploy) ? 1 : 0
  name                 = "ecr"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}


module "vpc" {
  count   = var.aws-eks-deploy ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.18.1"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "eks" {
  count                           = var.aws-eks-deploy ? 1 : 0
  depends_on                      = [module.vpc]
  version                         = "v18.30.2"
  source                          = "terraform-aws-modules/eks/aws"
  cluster_name                    = "sequila"
  cluster_version                 = "1.23"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  subnet_ids                      = module.vpc[0].private_subnets
  vpc_id                          = module.vpc[0].vpc_id

  eks_managed_node_groups = {
    green = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }
}