DEVOPS Hands-on
Deploying Azure VM using Terraform + Adding monitoring using cAdvisor, Prometheus, Grafana


Table Of contents
Deploying Azure VM using Terraform and Adding monitoring using cAdvisor
References:
Error resolution
Step 01 : Install Terraform on windows
Step 02 : Install Azure CLI on Windows
Step 03 : Install VS code
Step 04: Using Terraform creating VM
Step 04.1:  versions.tf
Step 04.2: vm.tf
Creating with Private IP address only
Now to get the latest linux vm version use the following command
Now initiating connection
Checking configuration success without any error to Terraform
Now Applying the changes to terraform to Azure
Step 04.3 : Now to create : public IP address
Updating the changes in the terraform to Azure.
Step 04.4: All set getting in to Azure VM
Step 05: Now trying to perform Port tutorial with Dashboard with cAdvisor
Step 05.1 :This is a simple Docker image : Hello World
Step 05.2 : Creating shell script to automate the deployment of docker image: Hello world
Step 05.3 : Creating shell script to automate the deployment of docker image and dashboard monitoring images
Providing executing permissions
Final Output: Expected :
Step 06: Creating Load Balancer
Step 06.1: Adding NAT inbound rules to enable the ip address
Step 06.2: Connecting to a VM and deploying the docker script file.
Final Output Expected:
cAdvisor : Demo Docker-cadvisor-1
Demo Docker-prometheus-1 : http://132.18.679.965:9090
Demo Docker-grafana-1 : http://132.18.679.965:3000/login
Docker instance 1 demo docker-Dockerfile-1 : http://132.18.679.965:32768/
Docker instance 2 demo docker-Dockerfile-2 : http://132.18.679.965:32769/
Docker instance 3 demo docker-Dockerfile-3 : http://132.18.679.965:32770/
Appendix Version 1
Demo Docker-cadvisor-1 : http://132.18.679.965:8080/containers/
