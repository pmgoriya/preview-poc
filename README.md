# Preview Environment Setup - Complete Commands

## Prerequisites
- Minikube installed
- kubectl installed
- Helm installed
- Git repository already created with all files

---

## Setup Commands (Fresh Minikube Cluster)

### 1. Start Minikube
```bash
minikube delete --all
minikube start --cpus=4 --memory=8192 --driver=docker
minikube addons enable ingress
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
```

### 2. Get Minikube IP
```bash
minikube ip
# Save this IP - you'll need it to access preview URLs
```

### 3. Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
```

### 4. Create Self-Signed ClusterIssuer
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

### 5. Install Argo CD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 6. Start Minikube Tunnel (NEW TERMINAL - Keep Running)
```bash
# Open a NEW terminal and run:
sudo minikube tunnel
# Enter password and leave this running
```

### 7. Port-Forward Argo CD UI (ANOTHER NEW TERMINAL - Keep Running)
```bash
# Open ANOTHER new terminal and run:
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Leave this running
```

### 8. Get Argo CD Admin Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 9. Login to Argo CD CLI (Optional)
```bash
# Get password from step 8, then:
argocd login localhost:8080 --username admin --password <YOUR_PASSWORD> --insecure
```

### 10. Apply ApplicationSet
```bash
# Navigate to your Git repo directory first
cd ~/preview-poc  # Or wherever your repo is

# Apply the ApplicationSet
kubectl apply -f applicationset.yaml
```

### 11. Wait for ApplicationSet to Detect Environments
```bash
# ApplicationSet polls Git every 3 minutes
echo "Waiting 3 minutes for ApplicationSet to sync..."
sleep 180

# Check if Applications were created
kubectl get applications -n argocd
```

### 12. Force Sync Applications
```bash
# Sync all preview applications
argocd app sync -l app.kubernetes.io/name=preview-envs

# Or sync individual ones
argocd app sync preview-pr-1
argocd app sync preview-pr-2
```

### 13. Verify Deployments
```bash
# Check all preview namespaces
kubectl get namespaces | grep preview

# Check resources in PR-1
kubectl get all,ingress,certificate -n preview-pr-1

# Wait for certificates to be ready
kubectl wait --for=condition=ready certificate -l app.kubernetes.io/instance=pr-1 -n preview-pr-1 --timeout=120s
```

### 14. Access Preview Environments
```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Test PR-1
curl -k https://pr1.$MINIKUBE_IP.sslip.io

# Test PR-2
curl -k https://pr2.$MINIKUBE_IP.sslip.io

# Print URLs
echo "PR-1: https://pr1.$MINIKUBE_IP.sslip.io"
echo "PR-2: https://pr2.$MINIKUBE_IP.sslip.io"
```

---

## Accessing Argo CD UI

**URL:** http://localhost:8080  
**Username:** `admin`  
**Password:** (from step 8)

---

## Useful Commands

### Check Application Status
```bash
# List all applications
kubectl get applications -n argocd

# Get detailed status
argocd app get preview-pr-1

# Watch sync progress
argocd app get preview-pr-1 --watch
```

### Force Resync
```bash
# Hard refresh (re-applies everything)
argocd app sync preview-pr-1 --force --prune
```

### Check Resources
```bash
# All resources in namespace
kubectl get all,ingress,certificate -n preview-pr-1

# Check certificate status
kubectl get certificate -n preview-pr-1
kubectl describe certificate pr-1-tls -n preview-pr-1

# Check ingress
kubectl describe ingress -n preview-pr-1

# Check pod logs
kubectl logs -n preview-pr-1 -l app.kubernetes.io/instance=pr-1
```

### Debug Issues
```bash
# Check Argo CD ApplicationSet controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Verify DNS resolution
nslookup pr1.$(minikube ip).sslip.io
```

### Add New Preview Environment
```bash
# In your Git repo, create new environment
MINIKUBE_IP=$(minikube ip)
mkdir -p environments/pr-3

cat > environments/pr-3/values.yaml <<EOF
content:
  message: "Hello from PR-3!"

ingress:
  enabled: true
  className: nginx
  host: pr3.$MINIKUBE_IP.sslip.io
  tlsSecretName: pr-3-tls
EOF

# Commit and push
git add environments/pr-3
git commit -m "Add PR-3 environment"
git push

# Wait 3 minutes or force sync
sleep 180
kubectl get applications -n argocd
argocd app sync preview-pr-3
```

### Delete Preview Environment
```bash
# Delete from Git (Argo CD will auto-cleanup)
git rm -rf environments/pr-1
git commit -m "Remove PR-1"
git push

# Or manually delete
kubectl delete application preview-pr-1 -n argocd
```

---

## Cleanup

### Delete Everything
```bash
# Delete ApplicationSet
kubectl delete applicationset preview-envs -n argocd

# Delete all preview namespaces
kubectl delete namespace -l created-by=preview-envs

# Delete Argo CD
kubectl delete namespace argocd

# Delete cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Delete Minikube cluster
minikube delete --all
```

---

## Troubleshooting

### Application Stuck in "Syncing"
```bash
argocd app sync preview-pr-1 --force --prune
```

### Certificate Not Ready
```bash
# Check certificate status
kubectl describe certificate pr-1-tls -n preview-pr-1

# Delete and recreate
kubectl delete certificate pr-1-tls -n preview-pr-1
argocd app sync preview-pr-1
```

### Ingress Not Working
```bash
# Restart ingress controller
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

# Make sure minikube tunnel is running
sudo minikube tunnel
```

### DNS Not Resolving
```bash
# Check DNS resolution
nslookup pr1.$(minikube ip).sslip.io

# If wrong, add to /etc/hosts
echo "$(minikube ip) pr1.$(minikube ip).sslip.io" | sudo tee -a /etc/hosts
```

### Can't Access URL
```bash
# Test service directly
kubectl port-forward -n preview-pr-1 svc/pr-1 8081:80
curl http://localhost:8081

# Test with Host header
curl -k -H "Host: pr1.$(minikube ip).sslip.io" https://$(minikube ip)
```

---

## Quick Reference

| Component | Access |
|-----------|--------|
| Argo CD UI | http://localhost:8080 |
| Argo CD User | admin |
| Argo CD Password | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| Preview URL Pattern | `https://pr<NUMBER>.<MINIKUBE_IP>.sslip.io` |
| Minikube IP | `minikube ip` |

---

## Expected Timeline

- Minikube start: **~2 minutes**
- cert-manager install: **~1 minute**
- Argo CD install: **~3 minutes**
- ApplicationSet sync: **~3 minutes**
- Certificate issuance: **~30 seconds**
- **Total: ~10 minutes** from zero to working preview environment

---

## Notes

- Keep `minikube tunnel` running in a separate terminal
- Keep `kubectl port-forward` running for Argo CD access
- ApplicationSet polls Git every 3 minutes by default
- Self-signed certificates will show browser warnings (this is expected)
- Use `pr<NUMBER>` format in hostnames (not `app-pr-<NUMBER>`) for sslip.io compatibility