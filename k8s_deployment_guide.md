# Kubernetes Local Cluster Deployment Guide

To safely test and validate your architecture using your Windows ecosystem (Docker Desktop and Kali Linux WSL 2), follow these simple steps to spin up the local cluster and launch your application across 3 scalable pods.

## Phase 1: Enabling Kubernetes Locally
The absolute easiest and most robust method utilizing your current environment is the native Kubernetes cluster built right inside Docker Desktop. It natively shares networks between your Kali WSL2 instance and your Windows Host!

1. Open **Docker Desktop** on Windows.
2. Go to the Settings Gear Icon ⚙️ (Top Right).
3. Select **Kubernetes** on the left sidebar.
4. Check **"Enable Kubernetes"** and hit Apply & Restart. (This can take 2-5 minutes to download initially).

## Phase 2: Verify WSL2 Tooling (Kali Linux)
Open your Kali Linux WSL2 console. You should have `kubectl` installed. If it's linked natively to Docker Desktop, it will work instantly.
```bash
# Verify your node is alive and connected
kubectl get nodes
```

## Phase 3: Building your Docker Image Locally
Because we want Kubernetes to run your specific application code, we need to build the Docker image into Docker Desktop's local registry.
In your Kali terminal, navigate to your root project directory and run:
```bash
docker build -t todo-app-v2:latest .
```
*(If Docker daemon isn't responding in WSL natively, you can run this exact command in Windows PowerShell directly—Docker Desktop unifies the images!)*

## Phase 4: Deploying to the Cluster
We have created the necessary configurations inside the `k8s` folder designed to launch a MongoDB stateless engine alongside 3 concurrent `todo-app` pods.

Inside your console, execute the configurations natively:
```bash
# 1. Deploy the MongoDB Database & Service
kubectl apply -f k8s/mongodb.yaml

# 2. Deploy your 3 Node Application Pods & Service
kubectl apply -f k8s/app.yaml
```

## Phase 5: Validating It Works!
You can watch your pods spin up live:
```bash
kubectl get pods
```
You should see 1 `mongodb` pod and 3 unique `todo-app` pods!

**Testing locally:**
The `todo-app-service` is exposed as a `NodePort`. Since you enabled it via Docker Desktop, you can interact securely with your cluster by forwarding the deployment port natively to Windows:
```bash
kubectl port-forward service/todo-app-service 5000:5000
```
Then navigate your browser to `http://localhost:5000/`. Traffic will automatically load balance intelligently across all 3 of your Node application pods safely behind the scenes!

## Cleanup
When your validation test is complete, tear it down softly:
```bash
kubectl delete -f k8s/app.yaml
kubectl delete -f k8s/mongodb.yaml
```
