# Connect to k8s cluster

1. Login into AWS
2. use ```aws login``` command to auth your aws cli
3. use ```aws eks update-kubeconfig --region eu-central-1 --name example-karpenter``` to generate kubeconfig (switch region and EKS cluster name)