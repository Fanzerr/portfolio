Objective
Package and deploy FleetDM to a local Kubernetes cluster using Helm.
1. Helm Chart
Create a public Helm chart that deploys:
FleetDM Server
MySQL 
Redis 
2. Local cluster
Include a Makefile with the following targets:
make cluster — create local cluster (Minikube or Kind)
make install — install the Helm chart
make uninstall — remove all deployed resources
3. Documentation
Provide a README.md that includes:
Installation & teardown instructions
Verification steps to confirm FleetDM, MySQL, and Redis are operational
4. Enhancements
Set up a basic CI pipeline to release new Helm chart versions.
Expose the FleetDM UI and ensure that FleetDM is reachable by agents
Automatically run fleet prepare db on fresh install
