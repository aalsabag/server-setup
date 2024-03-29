sudo apt-get update && apt-get upgrade
sudo apt-get --assume-yes install vim git
####### Docker install
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
####### K8s install

# letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# kube packages
sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update

sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo swapoff -a
sudo kubeadm init

# add user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# install weavenet
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# helm install
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm -rf get_helm.sh

# untaint master
kubectl taint nodes --all node-role.kubernetes.io/master-
# install ingress
kubectl create namespace ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --devel --version 4.0.0-beta.3
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.49.0/deploy/static/provider/cloud/deploy.yaml

# install cert manager
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.5.0 --set installCRDs=true

# create cluster issuer
tee -a cluster-issuer.yaml << EOF
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: macalsabag@hotmail.com
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
EOF


# install dynamic dns from namecheap
sudo apt-get install -y ddclient net-tools openssh-server

# REPLACE PASSWORD
sudo tee -a /etc/ddclient.conf << EOF
###############################
# ddclient.conf
# namecheap
###############################
use=web, web=dynamicdns.park-your-domain.com/getip
protocol=namecheap
server=dynamicdns.park-your-domain.com
login=alsabagtech.com
password=''
www
EOF

# MetalLB
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

tee -a metallb-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.19-192.168.1.20
EOF
kubectl apply -f metallb-config.yaml

## Enabling port forwarding 80 to 80
# Add this to pod spec of cert manager
## hostAliases:
#      - hostnames:
#        - alsabagtech.com
#        - bacteria.alsabagtech.com
#        - bacteria-backend.alsabagtech.com
#        ip: 192.168.1.246


#keep container running
#apiVersion: v1
#kind: Pod
#metadata:
#  name: ubuntu
#spec:
#  containers:
#  - name: ubuntu
#    image: ubuntu:latest
#    # Just spin & wait forever
#    command: [ "/bin/bash", "-c", "--" ]
#    args: [ "while true; do sleep 30; done;" ]

#Enable inbound traffic
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
sudo iptables -I INPUT -p tcp -m tcp --dport 32400 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 1935 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 6443 -j ACCEPT
# Plex
curl https://downloads.plex.tv/plex-keys/PlexSign.key | sudo apt-key add -
echo deb https://downloads.plex.tv/repo/deb public main | sudo tee /etc/apt/sources.list.d/plexmediaserver.list
sudo apt-get install -y apt-transport-https
sudo apt-get update
sudo apt-get install -y plexmediaserver
sudo tee -a /etc/ufw/applications.d/plexmediaserver << EOF
[plexmediaserver]
title=Plex Media Server (Standard)
description=The Plex Media Server
ports=32400/tcp|3005/tcp|5353/udp|8324/tcp|32410:32414/udp

[plexmediaserver-dlna]
title=Plex Media Server (DLNA)
description=The Plex Media Server (additional DLNA capability only)
ports=1900/udp|32469/tcp

[plexmediaserver-all]
title=Plex Media Server (Standard + DLNA)
description=The Plex Media Server (with additional DLNA capability)
ports=32400/tcp|3005/tcp|5353/udp|8324/tcp|32410:32414/udp|1900/udp|32469/tcp
EOF
sudo ufw app update plexmediaserver
sudo ufw allow plexmediaserver-all
sudo mkdir -p /opt/plexmedia/{movies,series}
sudo chown -R plex: /opt/plexmedia

# create certs
#sudo openssl genrsa -out key.pem 2048
#sudo openssl rsa -in key.pem -outform PEM -pubout -out public.pem
#sudo openssl pkcs12 -export -nocerts -inkey key.pem -out key.p12
#chown plex:plex key.p12
#sudo systemctl restart plexmediaserver


#Certbot configuration #MUST BE DONE ON ANOTHER MACHINE#!!
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get install certbot
sudo certbot certonly --manual --preferred-challenges=dns --email macalsabag@hotmail.com --server https://acme-v02.api.letsencrypt.org/directory --agre
e-tos -d *.alsabagtech.com
# Go into namecheap and create a TXT record where "*" is the host and value is the value provided
# your pub and priv key will be stored here /etc/letsencrypt/live/alsabagtech.com/fullchain.pem and here /etc/letsencrypt/live/alsabagtech.com/privkey.pem
# cat them out
# Create these two files vi ./cluster-wide.pem ./cluster-wide-key.pem the first containing the cert and the second containing the private key
k create secret tls cluster-wide-tls --cert=./cluster-wide.pem --key=./cluster-wide-key.pem -n kube-system
