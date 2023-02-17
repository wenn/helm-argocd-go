cluster := "kind-wenn"


.PHONY: build
build:
	docker build -t docker-gs-ping .

.PHONY: run
run: build
	docker run --publish 8888:8888 docker-gs-ping


# kind + argocd
.PHONY: argocd
argocd:
	$(MAKE) cluster
	$(MAKE) cluster-context
	$(MAKE) wait-for-password
	$(MAKE) argocd-setup
	@echo "\n\n\n"
	@echo "argocd user: admin"
	@echo "argocd password: password"
	@echo "run 'make serve'"

.PHONY: cluster
cluster: kind-delete kind-create apply-argocd

.PHONY: argocd-setup
argocd-setup: login change-password add-cluster add-repo

.PHONY: ensure-context
ensure-context:
	@test $$(kubectx -c) = ${cluster} || (echo "wrong context [ $$(kubectx -c) ]" && exit 1)

.PHONY: cluster-context
cluster-context:
	kubectx ${cluster}

.PHONY: apply-argocd
apply-argocd: ensure-context
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

.PHONY: kind-create
kind-create:
	kind create cluster --name wenn --config kind.yaml

.PHONY: kind-delete
kind-delete:
	kind delete cluster --name wenn

.PHONY: kind-create
kind-reset: kind-delete kind-create

.PHONY: wait-for-password
wait-for-password:
	@echo "\nwaiting for argocd password ... takes a few minutes."
	@for i in {1..120}; do $(MAKE) password-check &>/dev/null; test $$? = 0 && break || sleep 1; done
	@$(MAKE) password-check &>/dev/null; test $$? = 0 && echo "found init secret\n" || echo "failed to load init secret\n"
	#TODO use kubectl wait

.PHONY: password-check
password-check:
	@kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null

.PHONY: password
password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

.PHONY: login
login: ensure-context
	argocd login \
		--insecure \
		--port-forward 8080:80 \
		--port-forward-namespace argocd \
		--username admin \
		--password $$(make password)

.PHONY: change-password
change-password:
	@argocd account update-password \
		--account admin \
		--current-password $$(make password) \
		--new-password password \
		--insecure \
		--port-forward-namespace argocd

.PHONY: add-cluster
add-cluster: ensure-context
	argocd cluster add ${cluster} \
		-y \
		--in-cluster \
		--insecure \
		--port-forward-namespace argocd
	sleep 10 # argocd takes time to resolve state, require if need to pipe dependent commands.

.PHONY: add-repo
add-repo:
	argocd app create helm-argocd-go \
		--repo https://github.com/wenn/helm-argocd-go.git \
		--path chart \
		--dest-server https://kubernetes.default.svc \
		--dest-namespace default \
		--insecure \
		--port-forward-namespace argocd

.PHONY: serve
serve:
	kubectl port-forward svc/argocd-server -n argocd 8080:443
