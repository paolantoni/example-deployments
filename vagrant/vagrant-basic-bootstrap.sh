#!/usr/bin/env bash

# Increase No of HPgs as required from sogno demo documentation
echo 1024 | sudo tee /proc/sys/vm/nr_hugepages

sudo ufw disable
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common net-tools


#installing docker
if ! command -v docker &> /dev/null
then
    echo "------- Docker could not be found let's install it -------"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get install -y docker-ce 
    # adding user vagrant to docker group
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start  docker
fi

#installing kubernetes
if ! command -v kubelet &> /dev/null
then
    echo "------- Kubernetes could not be found let's install it -------"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo bash -c 'echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list'
    sudo apt-get update
    sudo sudo apt-get install -y kubelet kubeadm kubectl
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
fi

##installing helm
if ! command -v helm &> /dev/null
then
    echo "------- Helm could not be found let's install it -------"
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install -y helm
    sudo helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add sogno https://sogno-platform.github.io/helm-charts
    helm repo add influxdata https://influxdata.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
fi
#

##installing k3s
if ! command -v k3s &> /dev/null
then
    echo "------- K3S could not be found let's install it -------"
    curl -sfL https://get.k3s.io | sh -
    sudo chown -R vagrant /etc/rancher/k3s/
    sudo helm --kubeconfig /etc/rancher/k3s/k3s.yaml list
    ##getting pid of installation to wait until completed
    PID_K3S_INSTALLATION=$!
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    #appending variable to bashrc if not exists (to prevent mutliple lines added after repeated provision executions)
    grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
    ##must wait web interface of k3s is available to prevent errors on provisioning
    wait $PID_K3S_INSTALLATION
fi

echo "Pods running:"
k3s kubectl get pods --all-namespaces -o wide

echo "cluster info"
k3s kubectl cluster-info

if [ ! -d "example-deployments" ] 
then
  #checkout examples demo
  git clone https://github.com/sogno-platform/example-deployments.git
  rm -rf ./example-deployments/vagrant    
fi