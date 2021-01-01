# server-setup
A repository for installing necessary tools for a fresh home Ubuntu Server

On a fresh install of Ubuntu 20.04 LTS executing this script will
1. Install Docker
2. Install Kubernetes
3. Setup networking through WeaveNet
4. Install Helm
5. Untaint the master node (for single node clusters)
6. Install cert manager
7. Create a cluster issuer

Execute
```
chmod 700 setup.sh
./setup.sh
```
