kubectl create namespace bacteria
git clone https://github.com/aalsabag/Enterobacteriaceae.git
cd Enterobacteriaceae/mysql
k apply -f bacteria-db-deploy.yaml

cd ../bacteria-backend
k apply -f bacteria-backend-deploy.yaml

cd ../bacteria-frontend
k apply -f bacteria-frontend-deploy.yaml

