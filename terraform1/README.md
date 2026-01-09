# Task

You've joined a new and growing startup.

The company wants to build its initial Kubernetes infrastructure on AWS. The team wants to leverage the latest autoscaling capabilities by Karpenter, as well as utilize Graviton and Spot instances for better price/performance.

They have asked you if you can help create the following:

    Terraform code that deploys an EKS cluster (whatever latest version is currently available) into a new dedicated VPC

    The terraform code should also deploy Karpenter with node pool(s) that can deploy both x86 and arm64 instances
