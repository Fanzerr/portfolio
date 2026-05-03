cluster:
	if [[ $(which minikube) ]]; then
	  minikube start --addons=ingress --keep-context=true --kubernetes-version='v1.33.10'
	else
	  echo "ERROR: Minikube not detected" > &2
	fi
