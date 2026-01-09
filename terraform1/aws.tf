locals {
  name   = "example-karpenter"
  region = "eu-central-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["eu-central-1a","eu-central-1b","eu-central-1c"]

  tags = {
    Example    = local.name
  }
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"


  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery" = local.name
  }

  tags = local.tags
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.11.0"


  name               = local.name
  kubernetes_version = "1.34"

  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = true
  enable_irsa                              = true

  control_plane_scaling_config = {
    tier = "standard"
  }

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    karpenter_on_demand = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        "karpenter.sh/controller" = "true"
        "capacity-type" = "on_demand"
      }
    },
    karpenter_spot = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"

      min_size     = 0
      max_size     = 3
      desired_size = 0

      labels = {
        "karpenter.sh/controller" = "true"
        "capacity-type" = "spot"
      }
    },
    karpenter_arm64 = {
      ami_type       = "BOTTLEROCKET_ARM_64"
      instance_types = ["t4g.small"]

      min_size     = 0
      max_size     = 3
      desired_size = 0

      labels = {
        "karpenter.sh/controller" = "true"
      }
    }
  }

  node_security_group_tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })

  tags = local.tags
}