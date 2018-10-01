#!/bin/bash

working_dir=`pwd`

clusterName=influx-grafana
zoneSelect=us-central1-f

###Creating Cluster in GKE with Default Values###
echo "Cluster for "InfluxDB and Grafana" is getting ready"
echo ""
gcloud container clusters create $clusterName --zone $zoneSelect --num-nodes=1 --machine-type=n1-standard-4 --image-type=ubuntu --node-labels=type=storage-and-monitoring --num-nodes=1

###Connecting with the Newly Created Cluster###
echo "Connecting to the Cluster"
gcloud container clusters get-credentials $clusterName --zone $zoneSelect --project etsyperftesting-208619
echo "Connected to the cluster"
tenant=$clusterName
		
echo ""

echo "Deploying Pods and Services"
echo "-------------------------------------"

kubectl create namespace $tenant

###Creating InfluxDB from YAML files###
echo ""
echo ""
kubectl create -n $tenant -f $working_dir/jmeter_influxdb_deploy.yaml
kubectl create -n $tenant -f $working_dir/jmeter_influxdb_svc.yaml
echo "Influx Part Created"

###Creating Grafana from YAML files###
echo ""
echo ""
kubectl create -n $tenant -f $working_dir/jmeter_grafana_deploy.yaml
kubectl create -n $tenant -f $working_dir/jmeter_grafana_svc.yaml
echo "Grafana Part Created"

###Creating Jenkins from YAML files###
echo ""
echo ""
kubectl create -n $tenant -f $working_dir/jmeter_jenkins_deploy.yaml
kubectl create -n $tenant -f $working_dir/jmeter_jenkins_svc.yaml
echo "Jenkins Part Created"

echo namespace = $tenant > $working_dir/tenant_export

sleep 30

###Creating Jmeter DB in Influx###
echo "Creating the Jmeter DB"
influxdb_pod=`kubectl get po -n $tenant | grep influxdb-jmeter | awk '{print $1}'`
kubectl exec -ti -n $tenant $influxdb_pod -- influx -execute 'CREATE DATABASE jmeter'

###Create the influxdb datasource in Grafana###
echo "Creating the Influxdb data source"
grafana_pod=`kubectl get po -n $tenant | grep jmeter-grafana | awk '{print $1}'`

kubectl exec -ti -n $tenant $grafana_pod -- curl 'http://admin:admin@127.0.0.1:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"jmeterdb","type":"influxdb","url":"http://jmeter-influxdb:8086","access":"proxy","isDefault":true,"database":"jmeter","user":"admin","password":"admin"}' 


echo "PersistantVolume Creation"
kubectl create -n $tenant -f $working_dir/influx-grafana-pv.yaml
kubectl create -n $tenant -f $working_dir/influx-grafana-pvc.yaml


###Displaying the links###
link=`kubectl get svc -n $tenant | awk '{print $4}' | tail -n +2`
grafana=`echo $link | awk '{ print $1 }'`
influxDB=`echo $link | awk '{ print $2 }'`

echo ""
echo ""
echo "Please load the IP in the browser for the Grafana Dashboard - http://$grafana/" 
echo ""
echo ""
echo "Please use this IP in the Backend Listener with port 8086 for JMX script - http://$influxDB"
echo ""
echo ""
echo "InfluxDB and Grafana is Completely Ready"

###Removing the Credentials###
rm /home/relvan/.kube/config

