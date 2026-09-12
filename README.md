# Devops-Infrastructure-Deployment

This repository contains a small DevOps deployment example for a Python network
monitor. It includes Terraform infrastructure definitions, an Ansible Docker
setup playbook, a Docker image, Kubernetes manifests, and a GitHub Actions
workflow that builds and publishes the image.

## Architecture

The intended flow is:

```text
Monitor.py -> Docker image -> Docker Hub -> Kubernetes
                                        ^
                                        |
             GitHub Actions on push to main
```

Terraform provisions an AWS EC2 instance and security group. Ansible installs
Docker on the remote host. Kubernetes runs two monitor replicas and provide a
ClusterIP service.

## Repository Structure

```text
devops-infrastructure-deployment/
├── .github/
│   ├── agents/
│   │   └── devops.agent.md
│   └── workflows/
│       └── Ci-Cd.yaml
├── Terraform/
│   └── Main.tf
├── ansible/
│   └── Deploy-playbook.yaml
├── app/
│   ├── Dockerfile
│   ├── Monitor.py
│   └── requirements.txt
└── kubernetes/
    ├── Deployment-k8s.yaml
    └── K8s-service.yaml
```

## Prerequisites

- Terraform and an AWS account with credentials configured.
- Ansible and SSH access to the provisioned Ubuntu host.
- Docker, kubectl, and access to a Kubernetes cluster.
- Docker Hub credentials stored in GitHub repository secrets named
    `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.

## Deployment

### 1. Provision AWS infrastructure

From the repository root:

```bash
cd Terraform
terraform init
terraform validate
terraform apply \
  -var='key_name=<your-aws-key-pair>' \
  -var='ssh_cidr_blocks=["<your-public-ip>/32"]'
```

The output `instancia_ip_publica` contains the EC2 public IP. The current
Terraform configuration uses `us-east-1` and creates a `t3.micro` by default.
SSH access is limited to the `ssh_cidr_blocks` value supplied at apply time.
NodePort access on port `32000` is disabled unless you explicitly provide
`nodeport_cidr_blocks`, for example:

```bash
terraform apply \
  -var='key_name=<your-aws-key-pair>' \
  -var='ssh_cidr_blocks=["<your-public-ip>/32"]' \
  -var='nodeport_cidr_blocks=["<trusted-client-ip>/32"]'
```

The security group does not open port `5000`; `Monitor.py` does not expose an
HTTP service on that port. Outbound traffic is restricted to HTTPS, DNS, and
ICMP for package downloads, name resolution, and network checks.

### 2. Configure the server with Ansible

Create an Ansible inventory containing the EC2 address, SSH user, and key, then
run the playbook:

```bash
cd ../ansible
ansible-playbook -i <inventory-file> Deploy-playbook.yaml
```

The playbook installs Docker and enables its service. It does not currently
install K3s, deploy the application, or configure the Kubernetes cluster.

### 3. Build and publish the image

The workflow `.github/workflows/Ci-Cd.yaml` runs on pushes to `main` and builds
`app/Dockerfile`. It publishes the following Docker Hub tags using the username
from `DOCKERHUB_USERNAME`:

```text
<DOCKERHUB_USERNAME>/monitor-app:latest
<DOCKERHUB_USERNAME>/monitor-app:v1
<DOCKERHUB_USERNAME>/monitor-app:<commit-sha>
```

La etiqueta `<commit-sha>` identifica una versión concreta de la imagen. Para
actualizar Kubernetes con una imagen nueva, usa la etiqueta generada por CI:

```bash
kubectl set image deployment/monitor-server \
  ping-monitor=<DOCKERHUB_USERNAME>/monitor-app:<commit-sha>
kubectl rollout status deployment/monitor-server
```

El campo `image` del Deployment debe contener una etiqueta concreta, por
ejemplo `osva3097/monitor-app:abc1234`. Kubernetes no reemplaza expresiones de
GitHub Actions dentro de `Deployment-k8s.yaml` automáticamente.

You can build the image locally with:

```bash
docker build -t monitor-app:local ./app
```

### 4. Deploy to Kubernetes

After publishing an image that your cluster can pull, apply the manifests from
the repository root:

```bash
kubectl apply -f kubernetes/Deployment-k8s.yaml
kubectl apply -f kubernetes/K8s-service.yaml
```

The service is configured as a NodePort on port `32000` and targets port `5000`.

## Monitor Output

`Monitor.py` pings `www.tibia.com`, `www.google.com`, and `8.8.8.8`, prints the
result, and appends timestamped entries to `monitor.log`:

```text
Probando www.tibia.com...
 [EXITO] OK: www.tibia.com responde en 48.25 ms
Probando www.google.com...
 [EXITO] OK: www.google.com responde en 12.10 ms
Probando 8.8.8.8...
 [EXITO] OK: 8.8.8.8 responde en 9.42 ms
Escaneo de servidores finalizado. Revisa monitor.log para mas detalles.
```

The latency values vary by environment. The container requires the `ping`
utility, which is installed by the Dockerfile through Alpine's `iputils`
package.

## Current Limitations

- `Monitor.py` is a command-line monitor and does not expose an HTTP API, even
  though the container and Kubernetes manifests declare port `5000`.
- The repository does not currently include an Ansible inventory file or a K3s
  installation task.