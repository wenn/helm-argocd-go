.PHONY: build
build:
	docker build -t docker-gs-ping .

.PHONY: run
run: build
	docker run --publish 8888:8888 docker-gs-ping


.PHONY: uninstall
uninstall:
	microk8s uninstall

.PHONY: install
install:
	microk8s install

.PHONY: apply
apply:
	microk8s kubectl create namespace argocd
	microk8s kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

.PHONY: dns
dns:
	microk8s enable dns && microk8s stop && microk8s start

.PHONY: kubeconfig
kubeconfig:
	@microk8s config > /tmp/microk8x.conf
	@yq eval-all '. as $$item ireduce ({}; . *+ $$item)' ~/.kube/config.backup /tmp/microk8s.conf

.PHONY: reset
reset: uninstall install dns apply kubeconfig


## manual
.PHONY: port-forward
port-forward:
	microk8s kubectl port-forward svc/argocd-server -n argocd 8080:443

.PHONY: secret
secret:
	microk8s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

.PHONY: login
login:
	argocd login

.PHONY: add-cluster
add-cluster:
	argocd cluster add microk8s

add-repo:
	argocd app create helm-argocd-go --repo https://github.com/wenn/helm-argocd-go.git --path chart --dest-server https://kubernetes.default.svc --dest-namespace default
