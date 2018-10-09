#!/bin/bash

working_dir=`pwd`

### Defining Functions ###

fileValidate(){
if [ -f $1 ];then
 
  return 0

else

   echo "File not exists in `pwd` or entered wrong file Name. Please Check";
   return 1;

fi
}

###########################
clusterCreate(){
clusterName=${regionSelect}-cluster

gcloud container clusters create $clusterName --zone $zoneSelect --num-nodes=1 --machine-type=n1-standard-2 --image-type=ubuntu --node-labels=type=master

gcloud container node-pools create slave --cluster $clusterName --zone $zoneSelect --machine-type=n1-standard-8 --image-type=ubuntu --node-labels=type=slave --num-nodes=1

gcloud container clusters get-credentials $clusterName --zone $zoneSelect --project etsyperftesting-208619
}

###########################
deleteCluster(){
delete=true

while $delete;

do

read -p "Do you want to delete the cluster [y/n]: " deleteCluster

        if [[ $deleteCluster == 'y' || $deleteCluster == 'Y' ]]; then

                gcloud container clusters delete $clusterName --zone $zoneSelect --quiet

        elif [[ $deleteCluster == 'n' || $deleteCluster == 'N' ]]; then

                delete=false;
        else
                echo  "Enter a valid response y or n ";
                delete=true;
        fi

delete=false    

done
}

#########################
startTest(){
startTest=true

while $startTest; 

do	

read -p "Your Test is ready.. Press Y to start and N to exit [Y/n]: " startStatus

	if [[ $startStatus == 'y' || $startStatus == 'Y' ]]; then

 		echo "Starting the Test"

            	kubectl exec -it -n $tenant $master_pod -- /jmeter/load_test $jmxFile &

		sleep 30

                read -p "Do you want to stop the test [Y/n]: " abort

                        if [[ $abort == 'y' || $abort == 'Y' ]]; then
                                
				kubectl -n $tenant exec -ti $master_pod -- bash /jmeter/apache-jmeter-4.0/bin/stoptest.sh
                                
				sleep 15
				
				startTest=false;

                        elif [[ $abort == 'n' || $abort == 'N' ]]; then

                                findDuration

                        else

                                echo  "Wrong Response.Please wait until the test complete."

                                findDuration

                        fi 
		startTest=false;
	elif [[ $startStatus == 'n' || $startStatus == 'N' ]]; then

	       	startTest=false;

        else

		echo  "Enter a valid response y or n: "

		startTest=true;

	fi

done
}

##################################
initializePods(){

tenant=$clusterName

kubectl create namespace $tenant

kubectl create -n $tenant -f $working_dir/jmeter_slaves_deploy.yaml

kubectl create -n $tenant -f $working_dir/jmeter_slaves_svc.yaml


kubectl create -n $tenant -f $working_dir/jmeter_master_configmap.yaml

kubectl create -n $tenant -f $working_dir/jmeter_master_deploy.yaml

sleep 30

master_pod=`kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}'`

kubectl exec -ti -n $tenant $master_pod -- cp  /load_test  /jmeter/load_test

kubectl exec -ti -n $tenant $master_pod -- chmod 755 /jmeter/load_test

}

####################################
findDuration(){

time=true

while $time;

do

cat $jmxFile | grep "ThreadGroup.duration" >/dev/null 2>&1

if [ $? -eq '0' ]; then

	value=`cat $jmxFile | grep "ThreadGroup.duration" | sed 's/[^0-9]*//g'`

	echo "Script will run for $value seconds"

	wait=`expr $value + 10`

	sleep $wait
fi

time=false

done
}

###################################
jmxUploader(){

jmxUpload=true

while $jmxUpload;

do

	read -p "Enter jmx file: " jmxFile

	fileValidate $jmxFile

	if [ $? != 0 ]; then

		jmxUpload=true;

	else

		master_pod=`kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}'`

		kubectl exec -it -n $tenant $master_pod -- bash -c "echo 35.227.203.198 www.etsy.com etsy.com openapi.etsy.com api.etsy.com >> /etc/hosts"

		kubectl cp $jmxFile -n $tenant $master_pod:/$jmxFile

		echo "JMX Copy process completed"

		jmxUpload=false

	fi

done

}

#################################
csvUploader(){

read -p "Do you want to pass csv file [y/n] " csvStatus

csvUpload=true

while $csvUpload;

do

	if [[ $csvStatus == 'y' || $csvStatus == 'Y' ]];then

		csvVerify=true

		while $csvVerify;

		do

		read -p "Enter csv file : " csv

		fileValidate $csv

			if [ $? != 0 ]; then

                		csvVerify=true

        		else

				csvVerify=false

			fi

		done

	elif [[ $csvStatus == 'n' || $csvStatus == 'N' ]];then

		csvUpload=false

	else

   		echo  "Enter a valid response y or n ";

   		csvUpload=true

	fi

echo $csv >> file.csv

read -p "Do you have another CSV [Y/n]: " multiCSV

	if [[ $multiCSV == 'y' || $multiCSV == 'Y' ]]; then

   		csvUpload=true;

	elif [[ $multiCSV == 'n' || $multiCSV == 'N' ]]; then

                csvUpload=false;

	else

		echo "Enter a valid response Y or N: "

		csvUpload=true;

	fi

done

}

#########################################
copyCSVfiles(){

slave_pod=`kubectl get po -n $tenant | grep jmeter-slave | awk '{print $1}'`

echo "Please wait for few moments.. we are copying the CSV file"

	for i in $slave_pod

        do

        	kubectl exec -ti -n $tenant $i -- mkdir -p /jmeter/apache-jmeter-4.0/bin/csv/

        	kubectl exec -it -n $tenant $i -- bash -c "echo 35.227.203.198 www.etsy.com etsy.com openapi.etsy.com api.etsy.com >> /etc/hosts"

		copyCSV=`cat file.csv`                                        

			for j in $copyCSV

			do

	        		kubectl cp $j -n $tenant $i:/jmeter/apache-jmeter-4.0/bin/csv/$j

				echo "Copying.."

			done

	done

}

###Function Definition over###

multiRegion=true

while $multiRegion;

do

	read -p "Do you want to run Single-Region Test (or) Multi-Region Test [S/M]: " testType

		if [[ $testType == 'S' || $testType == 's' ]]; then

                        setupType="Single-Region"
                
		        multiRegion=false

                else

                        setupType="Multi-Region"

			echo "Multi-Region Yet to configure"

                        exit 0;
                fi

		### User Selecting Region and Zones ###

		echo -e "Available Regions in US\n-----------------------"

		echo -e "us-central1 | us-east1 | us-east4 | us-west1 | us-west2 \n"

  		read -p "Select the Region: " regionSelect

		case $regionSelect in
   				us-central1)

                			echo -e "Available Zones in $regionSelect\n----------------------------"
					
					echo ""
		
                			echo "us-central1-a | us-central1-b | us-central1-c | us-central1-f"
					
					echo ""
					
                			read -p "Select anyone Zone for the cluster: " zoneSelect

                			;;

       				us-east1)

              				echo -e "Available Zones in $regionSelect\n----------------------------"

					echo ""

					echo "us-east1-b | us-east1-c | us-east1-d"

					echo ""
					
			                read -p "Select anyone Zone for the cluster: " zoneSelect

			                ;;

			    	us-east4)

			                echo -e "Available Zones in $regionSelect\n----------------------------"
		
					echo ""

			                echo "us-east4-a | us-east4-b | us-east4-c"

					echo ""

			                read -p "Select anyone Zone for the cluster: " zoneSelect

			                ;;

			    	us-west1)

			                echo -e "Available Zones in $regionSelect\n----------------------------"

					echo ""

			                echo "us-west1-a | us-west1-b | us-west1-c"

					echo ""
					
			                read -p "Select anyone Zone for the cluster: " zoneSelect

			                ;;

				us-west2)	

			                echo -e "Available Zones in $regionSelect\n-----------------------------"

					echo ""

			                echo "us-west2-a | us-west2-b | us-west2-c"

					echo ""

			                read -p "Select anyone Zone for the cluster: " zoneSelect

			                ;;

			    	*)

			                echo -e "You Entered Wrong Input. I am exiting now..Please re-run the script."

					exit 1;

			                ;;

		esac
done

### calling cluster create function

clusterCreate

### calling initializePods function

initializePods

useExistingCluster=true

while $useExistingCluster;

do

rm -rf file.csv

### Uploading both jmx & csv files and copying files to the pods
	
jmxUploader

csvUploader

copyCSVfiles
	
### calling startTest function

startTest 
		
### Asking user for another test		

read -p "Do you want to run another script  with same $setupType setup [Y/n]?" again

	if [[ $again == 'y' || $again == 'Y' ]]; then

      		useExistingCluster=true

        elif [[ $again == 'n' || $again == 'N' ]]; then

		deleteCluster

	   	useExistingCluster=false

	else

              	read -p "Wrong Response! To start new test press 'Y' & to delete the cluster press 'N': " finalOption

			if [[ $finalOption == 'y' || $finalOption == 'Y' ]]; then 

				useExistingCluster=true

			elif [[ $finalOption == 'n' || $finalOption == 'N' ]]; then

                               	deleteCluster

			else

				echo "Wrong Choice again! Starting to delete the cluster"

				deleteCluster

			fi

	fi	

done
