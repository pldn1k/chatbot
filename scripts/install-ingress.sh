#!/bin/bash
set -e

echo "🌐 Installing Ingress Controller (without webhook)..."

# Полная очистка всех ресурсов
echo "🧹 Cleaning up old resources..."

# Удаляем IngressClass
kubectl delete ingressclass nginx 2>/dev/null || true
kubectl delete ingressclass ingress-nginx 2>/dev/null || true

# Удаляем ClusterRoles и ClusterRoleBindings
kubectl delete clusterrole ingress-nginx 2>/dev/null || true
kubectl delete clusterrole ingress-nginx-admission 2>/dev/null || true
kubectl delete clusterrolebinding ingress-nginx 2>/dev/null || true
kubectl delete clusterrolebinding ingress-nginx-admission 2>/dev/null || true

# Удаляем Webhook
kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true

# Удаляем namespace
kubectl delete namespace ingress-nginx --force --grace-period=0 2>/dev/null || true

# Ждем, пока namespace удалится
echo "⏳ Waiting for namespace to be deleted..."
while kubectl get namespace ingress-nginx 2>/dev/null; do
    sleep 2
done

# Создаем namespace заново
echo "📁 Creating namespace..."
kubectl create namespace ingress-nginx

# Устанавливаем без webhook
echo "🚀 Installing..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --set controller.resources.requests.cpu=100m \
    --set controller.resources.requests.memory=128Mi \
    --set controller.resources.limits.cpu=500m \
    --set controller.resources.limits.memory=512Mi \
    --set controller.service.type=NodePort \
    --set controller.admissionWebhooks.enabled=false \
    --wait

echo "✅ Ingress Controller installed!"

echo ""
echo "📊 Check status:"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass

echo ""
echo "🔗 To test ingress, add to /etc/hosts:"
echo "127.0.0.1 chatbot.local"


