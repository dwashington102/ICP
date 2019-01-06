#!/bin/sh

#======= CouchDB install size 1 GB
mkdir -p /k8s/data/couchdb  

#====== Kafka install size 10 GB Install @ Boot/Master to avoid network issues
mkdir -p /k8s/data/kafka   

#======= MongoDB install size 1 GB
mkdir -p /k8s/data/mongodb

#======= Zookeeper install size 1 GB
mkdir -p /k8s/data/zookeeper

#==== Cassandra install size 50 GB install @ Boot/Master to avoid network issues
mkdir -p /k8s/data/cassandra    

#======= Datalayer install size 1 GB
mkdir -p /k8s/data/datalayer 


# Confirm directories were created
ls -ltR /k8s

echo "Created Persistent Volume Storage directories"
echo -e "\n"
exit 0

