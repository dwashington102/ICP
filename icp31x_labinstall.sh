#!/bin/sh +x
# Create Date: Wed 19 Dec 2018 02:21:37 PM CST
# Last updated: Fri 04 Jan 2019 02:30:02 PM CST
# Author: David Washington (although this is such a hack job I don't want my name tied to it!)
#
# Purpose:  I am too lazy to keep typing commands to install ICP and ICAM.  So I created
# this hack job to avoid typing the commands.

check_uid () {
    if [[ $(whoami) != "root" ]] ; then
            echo "You must run this script as root. Goodbye."
            echo
            exit 1
        fi
}

install_docker () {
    /opt/install_media/icp-docker*bin --install
    if [ $? != 0 ]; then
        echo "Docker Failed to install"
        echo "Aborting installation of ICP.  Review /var/log/icp_docker.log to determine why docker failed to install"
        echo -e "\n"
	exit
    else
        echo "Docker successfully installed at the Master Node"
        echo -e "\n"
    fi
}

get_nodes () {
    echo -e "\n"
    kubectl get nodes
    get_critpods
} 

get_critpods () {
    echo -e "\n"
    kubectl get pods -o wide | grep --color=NEVER ^NAME && kubectl get pods -o wide| grep --color=NEVER -E "^ibmcloud.*-0 "
}

login_nsdefault () {
    echo -e "\n"
    cloudctl login https://mycluster.icp:8443 -n default -u admin -p admin
    if [ $? == 0 ]; then
        get_nodes
    else
       echo "Attempt to login to http://cluster.icp failed"
       exit 
    fi
}

get_downpods () {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
    printf "${GREEN}If the text \"0 unready pods and 0 ready pods\" appears above - this indicates a major install problem with IBM Cloud App Management${NC}\n"
    sleep 10
    kubectl get pods | grep --color=NEVER ibmcloud | grep --color=NEVER \ 0\/
    if [ $? == 0 ]; then
	    printf "${RED}Confirm if these PODS are healthy.${NC}\n"
            kubectl get pods | grep --color=NEVER ibmcloud | grep --color=NEVER \ 0\/
	    echo -e "\n"

    else
	    printf "${GREEN}No unhealthy pods detected.${NC}\n"
	    echo -e "\n"
    fi
}

get_ulimit() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
    vmmax=`sysctl -n vm.max_map_count`
    uNofile=`ulimit -n`
    uCore=`ulimit -c`

    printf "===================\nIf ulimit nofile setting is less than 32768 \nand/or core file is not set to \"unlimited\"-->\n"
    echo -e "\n"

    echo "Update the /etc/security/limits.conf file adding these lines:"
    echo "root soft nofile 32768"
    echo "root hard nofile 65536"
    echo "root hard core unlimited"
    echo "root soft core unlimited"
    echo -e "\n"
    echo "The root userid must log out and then login again for the ulimit settings to detect the changes made to the limits.conf file."

    echo -e "\n"
    echo "Current System Settings:"
    if [ \( ${uNofile} -lt 32768 \) -o \( ${uCore} != "unlimited" \) ]; then
        printf  "${RED}Ulimit Nofile - ${uNofile}\n"
        printf "Ulimit CORE - ${uCore}${NC}\n"
        echo "======================="
        echo -e "\n"
    else
        printf  "${GREEN}Ulimit Nofile - ${uNofile}\n"
        printf "Ulimit CORE - ${uCore}${NC}\n"
        echo "======================="
    fi
  
    printf "=====================\nVirtual Memory Settings\n"
    echo "If vm.max_map_count < 262144 increase the value using the command: sysctl -w vm.max_map_count=262144"
    echo -e "\n"

    echo "Current System Settings:"
    if [ ${vmmax} -lt 262144 ]; then
        printf "${RED}Current vm.max_map_count is ${vmmax}${NC}\n"
        echo "======================="
        echo -e "\n"
    else
        printf "${GREEN}Current vm.max_map_count is ${vmmax}${NC}\n"
        echo "======================="
        echo -e "\n"
    fi
    
    echo "=====================Physical Memory"
    echo "Total Physical Memory  at the Master Node should be at least 32 GB"
    free -h | grep --color=NEVER -v -i swap
    echo "=====================Virtual Memory Settings"
    echo -e "\n"

    printf "\t\t${RED}********STOP*************${NC}\n"
    echo -e "\n"

    echo "Before proceeding confirm if the above current systems values meet the requirements"
    printf "If any values above appear as ${RED}RED${NC} text ---- IBM Cloud Private and/or IBM Cloud App. Mgmt  will not fully install\n"

    sleep 7
    echo -e "\n"
    printf "Should we proceed? (y/n)\t"
    read myAnswer
    if [ $myAnswer == "n" ]; then 
        echo -e "\n"
    	echo "Correct system settings and then run script again."
        echo -e "\n"
	exit 
    else
    config_worker
    fi
}

config_worker () {
get_ipaddr
ssh root@$workerIP 'ls > /dev/null'
if [ $? != 0 ]; then
    echo "Sharing SSH Keys is not ENABLED Exiting..."
    echo -e "\n"
    exit 
else
    mediaDir='/opt/install_media'
    echo "Starting Worker Node actions..."
    ssh root@$workerIP 'mkdir /opt/install_media/'
    scp $mediaDir/k8s_pv_create.sh root@$workerIP:/opt/install_media/. 
    scp $mediaDir/icp*docker*.bin root@$workerIP:/opt/install_media/.
    ssh root@$workerIP 'chmod +x /opt/install_media/*'
    ssh root@$workerIP 'yum update -y'
    rpm -qa | grep --color=NEVER -m1 -E "^socat.*x86_64"
    if [ $? != 0 ]; then
        echo "Installing required socat package"
        socatPkg=`yum whatprovides socat | grep --color=NEVER ^soca | awk -F" : " '{print $1}'` 
        yum install -y $socatPkg
        ssh root@$workerIP '/opt/install_media/k8s_pv_create.sh'
        # Next step installs IBM docker at the Worker node maybe optional since the ICP 3.1.0 install should take care of installing docker at the work, but I do it anyway
        ssh root@$workerIP '/opt/install_media/icp*docker*bin --install'
        echo "Completed Worker Node Actions"
    else
        ssh root@$workerIP '/opt/install_media/k8s_pv_create.sh'
        # Next step installs IBM docker at the Worker node maybe optional since the ICP 3.1.0 install should take care of installing docker at the work, but I do it anyway
        ssh root@$workerIP '/opt/install_media/icp*docker*bin --install'
        echo "Completed Worker Node Actions"
    fi
fi
}

get_ipaddr () {
echo -e "\n"
export masterIP=`hostname -i`
echo "Master IP Address set to $masterIP "

export proxyFQN=`hostname`"."`dnsdomainname`
echo "Proxy FQN is set to Master Node's FQN: $proxyFQN"

echo -e "\n"
printf "Enter IP Address of Worker Node: "
read workerIP

echo -e "\n"
printf "${GREEN}Begin SSH key sharing between Master and Worker Node\n"
printf "In order to share SSH keys between the Master and Worker Node you must enter the root password for the Worker Node${NC}\n"
echo -e "\n"

ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys
printf "${GREEN}Enter the password for the root user at the worker node: $workerIP${NC}\n"
ssh-copy-id -i ~/.ssh/id_rsa.pub root@$workerIP
if [ $? != 0 ]; then
    printf "${RED}Invalid password for the root user at $workerIP${NC}\n"
    exit 
else
    check_hostname
    sleep 10
fi
}

# Fri 04 Jan 2019 02:28:32 PM CST
# Added check_hostname() in order to detect case of hostname.  Seems Calico has an issue when hostname is all UPPER CASE
check_hostname () {
    echo -e "\n"
    printf "\t${RED}**************STOP*******************${NC}\n"
    printf "Worker Node Hostname:\t"
    ssh root@$workerIP 'hostname'
    printf "Master Node Hostname:\t" 
    hostname
    echo -e "\n"
    echo "The hostname output above MUST be lower case OR the installation of IBM Cloud App Mgmt WILL FAIL"
    echo "See this URL: https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0.3/getting_started/known_issues.html#calico_case"
    echo -e "\n"
    printf "Should we proceed? (y/n)\t"
    read myAnswer
    if [ $myAnswer == "n" ]; then 
    	echo "Change the hostname(s) to user all lower case letters and then start the install script."
        echo -e "\n"
	exit 
    else
        echo -e "\n"
        echo "No other user input is required. The installer will be begin shortly. "
        echo "The installation will take about 2 hours to complete."  
        sleep 10
    fi
}

install_icp() {
    echo "************************************************"
    echo "Begin ICP deployment at Master Node..."
    get_installMedia


    cd ./icp310
    installPPA=$icpMedia
    #installPPA="/opt/install_media/icp310/$icpMedia"
    echo -e "\n"
    sleep 5

    chmod +x /opt/install_media/icp-docker*bin 
    #/opt/install_media/icp-docker*bin --install
    install_docker
    chmod +x /opt/install_media/k8s_pv_create.sh && /opt/install_media/k8s_pv_create.sh

    echo "Begin loading Docker images from ${installPPA}. This may take up to 30 minutes..."
    echo -e "\n"

    tar vxf $installPPA -O | docker load
    icpDir=`ls -ltr | grep --color=NEVER ibm-cloud*gz | cut -d" " -f9 | awk -F"x86_64." '{print "ibm-cloud-private-"$2}' | awk -F".tar.gz" '{print $1}'`

    #Comment out the step to hard code the /opt/ibm-cloud-private* directory
    #Mon 24 Dec 2018 02:05:05 AM CST
    #mkdir /opt/ibm-cloud-private-3.1.0 && cd /opt/ibm-cloud-private-3.1.0

    mkdir /opt/$icpDir && cd /opt/$icpDir
    echo -e "\n"

    # Thu 20 Dec 2018 10:36:05 PM CST -- 
    # It will be necessary to 'docker ps -a | grep --color=NEVER icp-inception | awk -F" " '{print $2}' | sort -u ' to avoid hard coding next line
    dockerImage=`docker images | grep --color=NEVER -m 1 icp-inception | awk -F" " '{print $1":"$2}'`
    docker run -v $(pwd):/data -e LICENSE=accept $dockerImage cp -r cluster /data
    #docker run -v $(pwd):/data -e LICENSE=accept ibmcom/icp-inception-amd64:3.1.0-ee cp -r cluster /data

    # Build the ./cluster/hosts file adding the master node and worker node IP address
    cat /dev/null > ./cluster/hosts
    echo "[master]" > ./cluster/hosts
    echo $masterIP >> ./cluster/hosts
    echo "[worker]" >> ./cluster/hosts
    echo $masterIP >> ./cluster/hosts
    echo $workerIP >> ./cluster/hosts
    echo "[proxy]" >> ./cluster/hosts
    echo $masterIP >> ./cluster/hosts
    mkdir -p cluster/images 
    rm ./cluster/ssh_key
    cp ~/.ssh/id_rsa ./cluster/ssh_key

    mv /opt/install_media/icp310/$installPPA ./cluster/images/.
    #mv /opt/install_media/icp310/ibm-cloud-private-x86_64-3.1.0.tar.gz ./cluster/images/.

    cd ./cluster
    echo $PWD
# To get a better understanding of what is taking place I added verbose tracing "-vvv" in order to get more details written to the log file
    docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster $dockerImage install -vvv | tee /tmp/docker_run_icp_install.`date +'%Y%m%d%s'.log`



#For debugging the docker run command we can pass "check" rather than install followed by uncommenting the entire block below
    #docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster $dockerImage check | tee /tmp/docker_run_icp_check.`date +'%Y%m%d%s'.log`
#    echo -e "\n"
#    printf "Did the docker run check complete successfully? (y/n)\t"
#    read icpAnswer
#    if [ ${icpAnswer} == "n" ]; then
#	echo "IBM Cloud Private install exiting."
#        exit 
#    else
#    docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster $dockerImage install -vvv | tee /tmp/docker_run_icp_install.`date +'%Y%m%d%s'.log`
#    fi
# End of section to uncomment

}

get_installMedia () {
    mkdir ./icp310 && mv ibm-cloud-private*.tar.gz ./icp310/.
    mkdir ./icam   && mv app_mgmt_server*.tar.gz ./icam/.
    export icpMedia=`ls ./icp310/ | grep --color=NEVER ibm-cloud-private`
    export camMedia=`ls ./icam/ | grep --color=NEVER app_mgmt_server`
    echo "Installation Media for IBM Cloud Private: ${icpMedia}"
    echo "Installation Media for IBM Cloud App Management: ${camMedia}"
}
 
install_cam () {
    echo "Begin ICAM deployment..."
    cd /opt/install_media/icam
    echo -e "\n"
    sleep 10
    cloudctl login -a https://mycluster.icp:8443 -u admin -p admin --skip-ssl-validation -c id-mycluster-account -n default
    #docker login required before running the 'cloudctl catalog' command or authentication error is encountered
    docker login mycluster.icp:8500 -u admin -p admin

    cloudctl catalog load-archive --archive $camMedia --registry mycluster.icp:8500

    tar xvf $camMedia charts
    
    chartsMedia=`ls ./charts/ibm-cloud-appmgmt*tgz`
    tar xvf $chartsMedia 
    #tar xvf charts/ibm-cloud-appmgmt-prod-1.2.0.tgz

    docker login mycluster.icp:8500 -u admin -p admin

    cloudctl catalog load-archive --archive $camMedia --registry mycluster.icp:8500 --repo local-charts
    cd ibm-cloud-appmgmt-prod
    sleep 10

    ./additionalFiles/prepare-pv.sh --size0 --releaseName ibmcloudappmgmt --cassandraNode $masterIP --mongoDBNode $workerIP --kafkaNode $masterIP --zookeeperNode $workerIP --couchdbNode $workerIP --datalayerNode $workerIP

    kubectl create -f ./additionalFiles/../yaml/


    ./additionalFiles/pre-install.sh --accept --releasename ibmcloudappmgmt --namespace default --masterip $masterIP --proxyip $masterIP --proxyhostname $proxyFQN --clustercadomain mycluster.icp --advanced

    kubectl create -f default-ibmcloudappmgmt-image-policy.yaml

    helm install --name ibmcloudappmgmt --values /opt/install_media/icam/ibm-cloud-appmgmt-prod/ibmcloudappmgmt.values.yaml /opt/install_media/icam/$chartsMedia --tls


    ./additionalFiles/post-install-setup.sh --releaseName ibmcloudappmgmt --namespace default --instanceName ibmcloudappmgmt --advanced

    # To set the tenantID use the following syntax
    #./additionalFiles/post-install-setup.sh --releaseName ibmcloudappmgmt --namespace default --instanceName ibmcloudappmgmt --advanced --tenantID cebed10c-0de9-4209-96db-acd02b46afc3
}

MAIN () {
check_uid
get_ulimit	
install_icp
install_cam
get_downpods
login_nsdefault
}

# Begin Work
MAIN

# Printing Login information to the ICP Console and accessing the CAM Dashboard
echo -e "\n"
echo "Login to the IBM Cloud Private Console using: \"https://$masterIP:8443\""
printf "Default userid: admin\t Default password: admin\n"

echo -e "\n"
echo "To access the ICAM within IBM Cloud Private:"
printf "\tSelect the Menu Icon (3 lines at the top left next to the text \"IBM Cloud Private\"\n"
printf "\t--> Workloads --> Brokered Services --> For ibmcloudappmgmt choose the \"Launch\" link\n"

# Just something to print
echo -e "\n"
printf "Master Node IP Address is $masterIP\nKubernetes Proxy is configured to run at Master Node using $proxyFQN\n"
echo "Worker Node IP Address: $workerIP"
echo -e "\n"
exit 0
