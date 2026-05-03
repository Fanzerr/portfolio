cluster:
	echo 
	if [ $$(which minikube) ]; then \
	  if [ "$$(minikube status | grep kubelet)" = "kubelet: Running" ]; then \
	    echo "Minikube cluster already running" >&2 ;\
	  else \
	    minikube start --addons=ingress --keep-context=true --kubernetes-version='v1.33.10' ;\
	  fi ;\
	else \
	  echo "ERROR: Minikube not detected" >&2 ;\
	fi

install:
	helm pull --untar https://github.com/Fanzerr/portfolio/raw/refs/heads/master/helm1/fleetdm-0.1.0.tgz ;\
	helm install fleet -n fleet --context minikube -f fleetdm/values.yaml fleetdm

uninstall:
	helm uninstall fleet -n fleet --context minikube