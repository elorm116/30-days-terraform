provider "aws" {
  region = var.region
}

# The Kubernetes provider is configured AFTER the EKS cluster exists.
# host and cluster_ca_certificate come from the EKS module outputs.
# Terraform's dependency graph ensures EKS is created first
# before the Kubernetes provider tries to connect.
#
# The exec block runs "aws eks get-token" to get a temporary
# authentication token — more secure than storing static credentials.

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
# -----------------------------
# VPC — EKS needs a VPC with private subnets
# -----------------------------
# We use the official VPC module — it creates:
# - VPC with the specified CIDR
# - Public subnets (for load balancers)
# - Private subnets (for EKS nodes — nodes should never be public)
# - NAT Gateway (allows private nodes to reach the internet for updates)
# - Internet Gateway (allows public subnets to reach the internet)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  # Spread across 3 AZs for high availability
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  # NAT Gateway allows private subnet nodes to pull container images
  # and receive updates without being publicly accessible
  enable_nat_gateway = true
  single_nat_gateway = true  # one NAT GW saves cost in dev

  # These tags are required by EKS to discover which subnets to use
  # for load balancers and node groups
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = "dev"
  }
}

# -----------------------------
# EKS CLUSTER
# -----------------------------
# The official EKS module handles the complexity of:
# - EKS control plane creation
# - IAM roles for the cluster and node groups
# - Security groups
# - Node group configuration
# - aws-auth ConfigMap for RBAC
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name    = var.cluster_name
  kubernetes_version = var.cluster_version

  # EKS nodes go in private subnets — never expose nodes publicly
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets


  # Allow your local machine to access the cluster API
  # needed for kubectl and for Terraform's Kubernetes provider
  endpoint_public_access = true
  endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true

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



  # Managed node groups — AWS manages the underlying EC2 instances
  # You just specify the size and instance type
  eks_managed_node_groups = {
    default = {
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.small"]

      tags = {
        Name = "${var.cluster_name}-node"
      }
    }
  }

  tags = {
    Name        = var.cluster_name
    Environment = "dev"
    Challenge   = "30DayTerraform"
  }
}

# -----------------------------
# KUBERNETES DEPLOYMENT
# -----------------------------
# Now that EKS exists and the Kubernetes provider is connected
# we can deploy workloads using Terraform's Kubernetes resources.
# This is identical to writing a Kubernetes YAML manifest
# but in HCL — Terraform manages the lifecycle.
resource "kubernetes_deployment_v1" "nginx" {
    depends_on = [module.eks.eks_managed_node_groups]
  metadata {
    name      = "nginx-deployment"
    namespace = "default"
    labels = {
      app = "nginx"
    }
  }

  spec {
    # Run 2 replicas for basic availability
    replicas = 2

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"

          port {
            container_port = 80
          }

          # Resource limits — important in production
          # prevents one container from consuming all node resources
          resources {
            limits = {
              cpu    = "250m"   # 0.25 CPU cores
              memory = "128Mi"  # 128 megabytes
            }
            requests = {
              cpu    = "125m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }

  # Wait for the deployment to be ready before Terraform
  # considers this resource successfully created
  timeouts {
    create = "10m"
  }
}

# Kubernetes Service — exposes the deployment
# LoadBalancer type creates an AWS ALB automatically
resource "kubernetes_service_v1" "nginx" {
  depends_on = [module.eks.eks_managed_node_groups]

  metadata {
    name      = "nginx-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    # LoadBalancer creates an AWS ELB to expose the service externally
    type = "LoadBalancer"
  }
}