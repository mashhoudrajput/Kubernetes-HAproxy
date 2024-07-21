#!/bin/bash

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
chmod 600 /root/.kube/config
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update
#helm search repo ingress-nginx -l
helm upgrade --install   ingress-nginx ingress-nginx/ingress-nginx   --namespace ingress-nginx   --set controller.service.type=NodePort  --set controller.service.nodePorts.http=30080 --set controller.service.nodePorts.https=30443  --version 4.10.0   --create-namespace
kubectl get svc -n ingress-nginx ingress-nginx-controller

kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.5.3 --set installCRDs=true

kubectl create namespace cattle-system
helm install rancher rancher-stable/rancher --namespace cattle-system --create-namespace --set hostname=rancher.heronos.com --set ingress.ingressClassName=nginx

kubectl create namespace dev-environment
aws ecr get-login-password --region eu-central-1 | kubectl create secret docker-registry ecr-secret --docker-server=142081895333.dkr.ecr.eu-central-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region eu-central-1) --namespace dev-environment
