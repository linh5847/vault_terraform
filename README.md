PreQuisites:-
===========
Install minikube, kubectl, vault on your local machine.

All methods are testing on MacOS only.

Steps:
=====

vault server -dev -dev-listen-address="0.0.0.0:8200" -dev-root-token-id="root" &
export VAULT_TOKEN=root
export VAULT_ADDR="http://0.0.0.0:8200"

minikube start --cpus 6 --memory 8192 --extra-config=apiserver.service-node-port-range=1-65535 --disk-size 80GB


EXTERNAL_VAULT_ADDR=$(minikube ssh "dig +short host.docker.internal" | tr -d '\r')
`insert the above IP into terraform *external_vault_addr* variable value`

KUBE_HOST$(minikube ip)
`insert this ip to *kubernetes_host* terraform variable value`

### Terraform Execution
```
cd components/blue_green
*terraform init -get=true -input=false -force-copy*
*terraform plan -var-file environments/blue-dev.tfvars*   
Pay attention to the namespace indexes. 

I believe I put in order vault, cert-manager and traefik. It is worth run the terraform plan first and adjust the index number.

My environment.
*vault* namespace[2], *cert-manager* namespace[0]. Your environment may be different

If it is different. Edit components/blue_green/vault.tf, cert_manager.tf and traefik.tf

*terraform apply -var-file environments/blue-dev.tfvars*
```
Retrieve the Kubernetes host URL
#KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')

### Terraform module
.

