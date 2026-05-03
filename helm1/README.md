# Pre-requsites
1. Helm 3 installed
2. Minikube installed

# Install

To spin-up minikube cluster, run:
```bash
make cluster
```

To install helm chart, run:
```bash
make install
```

# Teardown

To uninstall helm chart, run:
```bash
make uninstall
```

To teardown minikube cluster, run:
```bash
minikube delete
```

# Verification

1. Ensure all pods are running and migration is finished
```
kubectl get pods -n fleet --context minikube
```

2. When all pods are running, connect to fleetdm-ui

a)
```bash
kubectl get ing -n fleet --context minikube
```
Get ip address, add
```
<IP_address> fleet-ui.example.local
```
to /etc/hosts

Open http://fleet-ui-example.local in browser



b)
```bash
kubectl --context minikube port-forward -n fleet svc/fleet-service 8080
```

Open http://localhost:8080 in browser