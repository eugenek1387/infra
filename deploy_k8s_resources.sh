#!/bin/bash

echo "=== Getting k8s credentials and connecting to cluster..."

# Узнаем ks8s cluster-id и записываем его значение в переменные окружения
K8SCLUSTERID=$(yc managed-kubernetes cluster list --format json | jq -r '.[0].id')

# Настриваем kubeconfig для подключения к кластеру
yc managed-kubernetes cluster get-credentials $K8SCLUSTERID --external --force

echo "*** Done"

echo "=== Deploying Ingress controller ..."

# Экспортируем из tf output и записываем значение в переменные окружения
TF_DATA_DIR=/Users/evgeny/Documents/devopstrain/project/terraform/
STATIC_IP=$(terraform -chdir=$TF_DATA_DIR output -raw static_ip_address)

# Деплоим ingress-контроллер:
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --version 4.8.1 --set controller.service.loadBalancerIP=$STATIC_IP --namespace ingress-nginx --create-namespace

echo "*** Done"

echo "=== Deploying Cert-Manager..."

# Деплоим ресурсы cert-manager:
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
helm upgrade --install cert-manager bitnami/cert-manager --version 0.12.5 --set installCRDs=true --namespace cert-manager --create-namespace

echo "*** Done"

# Добавляем репу cockroachdb в helm
# helm repo add cockroachdb https://charts.cockroachdb.com/
# helm repo update

echo "=== CockroachDB deploying..."

# Деплоим cockroachdb с кастомным values
helm upgrade --install cockroachdb --values cockroachdb-values.yaml cockroachdb/cockroachdb --namespace cockroachdb --create-namespace

echo "*** Done"

# Проверяем релизы

helm list -A

echo "=== Waiting for Cert-Manager to run properly..."

sleep 30

echo "=== ClusterIssuer deploying..."

# Деплоим ClusterIssuer
kubectl apply -f cluster-issuer.yaml

echo "=== Checking clusterissuer objects"

kubectl get clusterissuers
kubectl get secrets -n cert-manager

echo "*** Done"

# Генерируем сертификат для ingress 

# echo "=== Generating Ingress certificate"

# kubectl apply -f certificate.yaml

# echo "*** Done"

# Деплоим helm-чарт с зависимостями (deps-chart)

echo "=== Installing deps-chart"

helm upgrade --install deps-chart ../charts/deps-chart/ -n deps --create-namespace

echo "*** Done"

# Деплоим helm-чарт с сервисами (service-chart)

echo "=== Installing service-chart"

helm upgrade --install jobber ../charts/service-chart/ --values ../charts/service-chart/values_jobber.yaml -n svc --create-namespace
helm upgrade --install leads ../charts/service-chart/ --values ../charts/service-chart/values_leads.yaml -n svc 
helm upgrade --install notif ../charts/service-chart/ --values ../charts/service-chart/values_notif.yaml -n svc 
helm upgrade --install quiz ../charts/service-chart/ --values ../charts/service-chart/values_quiz.yaml -n svc 
helm upgrade --install show ../charts/service-chart/ --values ../charts/service-chart/values_show.yaml -n svc 
helm upgrade --install uploader ../charts/service-chart/ --values ../charts/service-chart/values_uploader.yaml -n svc 
helm upgrade --install users ../charts/service-chart/ --values ../charts/service-chart/values_users.yaml -n svc 
helm upgrade --install app ../charts/service-chart/ --values ../charts/service-chart/values_app.yaml -n svc 
helm upgrade --install land ../charts/service-chart/ --values ../charts/service-chart/values_land.yaml -n svc

# echo "*** Completed"
