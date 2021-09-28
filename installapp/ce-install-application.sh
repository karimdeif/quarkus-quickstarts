#!/bin/bash

# CLI Documentation
# ================
# command documentation: https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create

# **************** Global variables

#export PROJECT_NAME=$MYPROJECT
export PROJECT_NAME=multi-tenancy-serverless
export RESOURCE_GROUP=default
export REGION="us-south"
export NAMESPACE=""
export STATUS="Running"

# ecommerce application container registry
export SERVICE_CATALOG_IMAGE="us.icr.io/multi-tenancy-cr/service-catalog:latest"
export FRONTEND_IMAGE="us.icr.io/multi-tenancy-cr/frontend:latest"

# URLs
export FRONTEND_URL=""
export SERVICE_CATALOG_URL=""

# AppID Service
export SERVICE_PLAN="graduated-tier"
export APPID_SERVICE_NAME="appid"
#export YOUR_SERVICE_FOR_APPID="appID-multi-tenancy-example-tsuedbro"
export YOUR_SERVICE_FOR_APPID="multi-tenancy-AppID-automated-serverless"
export APPID_SERVICE_KEY_NAME="multi-tenancy-AppID-automated-serverless-service-key"
export APPID_SERVICE_KEY_ROLE="Manager"
export TENANTID=""
export MANAGEMENTURL=""
export APPLICATION_DISCOVERYENDPOINT=""

# AppID User
export USER_IMPORT_FILE="appid-configs/user-import.json"
export USER_EXPORT_FILE="appid-configs/user-export.json"
export ENCRYPTION_SECRET="12345678"

# AppID Application configuration
export ADD_APPLICATION="appid-configs/add-application.json"
export ADD_SCOPE="appid-configs/add-scope.json"
export ADD_ROLE="appid-configs/add-roles.json"
export ADD_REDIRECT_URIS="appid-configs/add-redirecturis.json"
export APPLICATION_CLIENTID=""
export APPLICATION_TENANTID=""
export APPLICATION_OAUTHSERVERURL=""

# **********************************************************************************
# Functions definition
# **********************************************************************************

function setupCLIenvCE() {
  echo "**********************************"
  echo " Using following project: $PROJECT_NAME" 
  echo "**********************************"
  
  ibmcloud target -g $RESOURCE_GROUP
  ibmcloud target -r $REGION
  ibmcloud ce project get --name $PROJECT_NAME
  ibmcloud ce project select -n $PROJECT_NAME
  
  #to use the kubectl commands
  ibmcloud ce project select -n $PROJECT_NAME --kubecfg
  
  # NAMESPACE=$(kubectl get namespaces | awk '/NAME/ { getline; print $0;}' | awk '{print $1;}')
  # NAMESPACE=$(ibmcloud ce project get --name $PROJECT_NAME --output json | sed -n 's|.*"namespace":"\([^"]*\)".*|\1|p')
  NAMESPACE=$(ibmcloud ce project get --name $PROJECT_NAME --output json | grep "namespace" | awk '{print $2;}' | sed 's/"//g' | sed 's/,//g')
  echo "Namespace: $NAMESPACE"
  kubectl get pods -n $NAMESPACE

  CHECK=$(ibmcloud ce project get -n $PROJECT_NAME | awk '/Apps/ {print $2;}')
  echo "**********************************"
  echo "Check for existing apps? '$CHECK'"
  echo "**********************************"
  if [ $CHECK != 0 ];
  then
    echo "Error: There are remaining '$CHECK' apps."
    echo "Wait until all apps are deleted inside the $PROJECT_NAME."
    echo "The script exits here!"
    exit 1
  fi
 
}

# **** AppID ****

createAppIDService() {
    ibmcloud target -g $RESOURCE_GROUP
    ibmcloud target -r $REGION
    # Create AppID service
    ibmcloud resource service-instance-create $YOUR_SERVICE_FOR_APPID $APPID_SERVICE_NAME $SERVICE_PLAN $REGION
    # Create a service key for the service
    ibmcloud resource service-key-create $APPID_SERVICE_KEY_NAME $APPID_SERVICE_KEY_ROLE --instance-name $YOUR_SERVICE_FOR_APPID
    # Get the tenantId of the AppID service key
    TENANTID=$(ibmcloud resource service-keys --instance-name $YOUR_SERVICE_FOR_APPID --output json | grep "tenantId" | awk '{print $2;}' | sed 's/"//g')
    echo "Tenant ID: $TENANTID"
    # Get the managementUrl of the AppID from service key
    MANAGEMENTURL=$(ibmcloud resource service-keys --instance-name $YOUR_SERVICE_FOR_APPID --output json | grep "managementUrl" | awk '{print $2;}' | sed 's/"//g' | sed 's/,//g')
    echo "Management URL: $MANAGEMENTURL"
}

configureAppIDInformation(){

    #****** Set identity providers
    echo ""
    echo "-------------------------"
    echo " Set identity providers"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-custom.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/custom)
    echo ""
    echo "-------------------------"
    echo "Result custom: $result"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-facebook.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/facebook)
    echo ""
    echo "-------------------------"
    echo "Result facebook: $result"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-google.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/google)
    echo ""
    echo "-------------------------"
    echo "Result google: $result"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-clouddirectory.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/cloud_directory)
    echo ""
    echo "-------------------------"
    echo "Result cloud directory: $result"
    echo "-------------------------"
    echo ""

    #****** Add application ******
    echo ""
    echo "-------------------------"
    echo " Create application"
    echo "-------------------------"
    echo ""
    result=$(curl -d @./$ADD_APPLICATION -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/applications)
    echo "-------------------------"
    echo "Result application: $result"
    echo "-------------------------"
    APPLICATION_CLIENTID=$(echo $result | sed -n 's|.*"clientId":"\([^"]*\)".*|\1|p')
    APPLICATION_TENANTID=$(echo $result | sed -n 's|.*"tenantId":"\([^"]*\)".*|\1|p')
    APPLICATION_OAUTHSERVERURL=$(echo $result | sed -n 's|.*"oAuthServerUrl":"\([^"]*\)".*|\1|p')
    APPLICATION_DISCOVERYENDPOINT=$(echo $result | sed -n 's|.*"discoveryEndpoint":"\([^"]*\)".*|\1|p')
    echo "ClientID: $APPLICATION_CLIENTID"
    echo "TenantID: $APPLICATION_TENANTID"
    echo "oAuthServerUrl: $APPLICATION_OAUTHSERVERURL"
    echo "discoveryEndpoint: $APPLICATION_DISCOVERYENDPOINT"
    echo ""

    #****** Add scope ******
    echo ""
    echo "-------------------------"
    echo " Add scope"
    echo "-------------------------"
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./$ADD_SCOPE -H "Content-Type: application/json" -X PUT -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/applications/$APPLICATION_CLIENTID/scopes)
    echo "-------------------------"
    echo "Result scope: $result"
    echo "-------------------------"
    echo ""

    #****** Add role ******
    echo "-------------------------"
    echo " Add role"
    echo "-------------------------"
    #Create file from template
    sed "s+APPLICATIONID+$APPLICATION_CLIENTID+g" ./appid-configs/add-roles-template.json > ./$ADD_ROLE
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    #echo $OAUTHTOKEN
    result=$(curl -d @./$ADD_ROLE -H "Content-Type: application/json" -X POST -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/roles)
    echo "-------------------------"
    echo "Result role: $result"
    echo "-------------------------"
    echo ""
 
    #****** Import cloud directory users ******
    echo ""
    echo "-------------------------"
    echo " Cloud directory import users"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./$USER_IMPORT_FILE -H "Content-Type: application/json" -X POST -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/cloud_directory/import?encryption_secret=$ENCRYPTION_SECRET)
    echo "-------------------------"
    echo "Result import: $result"
    echo "-------------------------"
    echo ""
}

addRedirectURIAppIDInformation(){

    #****** Add redirect uris ******
    echo ""
    echo "-------------------------"
    echo " Add redirect uris"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    #Create file from template
    sed "s+APPLICATION_REDIRECT_URL+$WEBAPP_URL+g" ./appid-configs/add-redirecturis-template.json > ./$ADD_REDIRECT_URIS
    result=$(curl -d @./$ADD_REDIRECT_URIS -H "Content-Type: application/json" -X PUT -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/redirect_uris)
    echo "-------------------------"
    echo "Result redirect uris: $result"
    echo "-------------------------"
    echo ""
}

# **** application and microservices ****

function deployServiceCatalog(){

    ibmcloud ce application create --name service-catalog-a --image "$SERVICE_CATALOG_IMAGE" \
                                   --cpu "1" \
                                   --memory "2G" \
                                   --port 8081 \
                                   --rs test \
                                   --max-scale 1 \
                                   --min-scale 1 \
                                       
    ibmcloud ce application get --name service-catalog-a

    SERVICE_CATALOG_URL=$(ibmcloud ce application get --name service-catalog-a | grep "https://service-catalog-a." |  awk '/service-catalog-a/ {print $2}')
    echo "Set SERVICE CATALOG URL: $SERVICE_CATALOG_URL"

    # checkKubernetesPod "articles"
}

function deployFrontend(){

    ibmcloud ce application create --name frontend \
                                   --image "$FRONTEND_IMAGE" \
                                   --cpu "1" \
                                   --memory "2G" \
                                   --env VUE_APP_ROOT="/" \
                                   --env VUE_APP_WEBAPI="$WEBAPI_URL/articlesA" \
                                   --env VUE_APPID_CLIENT_ID="$APPLICATION_CLIENTID" \
                                   --env VUE_APPID_DISCOVERYENDPOINT="$APPLICATION_DISCOVERYENDPOINT" \
                                   --max-scale 1 \
                                   --min-scale 1 \
                                   --port 8080 

    ibmcloud ce application get --name frontend
    FRONTEND_URL=$(ibmcloud ce application get --name frontend | grep "https://frontend." |  awk '/frontend/ {print $2}')
    echo "Set FRONTEND URL: $FRONTEND_URL"

    # checkKubernetesPod "web-app"
}

function updateWebApp(){

    ibmcloud ce application update --name web-app \
                                   --env VUE_APP_ROOT="/" \
                                   --env VUE_APP_WEBAPI="$WEBAPI_URL/articlesA" \
                                   --env VUE_APPID_CLIENT_ID="$APPLICATION_CLIENTID" \
                                   --env VUE_APPID_DISCOVERYENDPOINT="$APPLICATION_DISCOVERYENDPOINT" \

    ibmcloud ce application get --name web-app
    WEBAPP_URL=$(ibmcloud ce application get --name web-app | grep "https://web-app." |  awk '/web-app/ {print $2}')
    echo "Set WEBAPP URL: $WEBAPP_URL"
    
    # checkKubernetesPod "web-app-00002"
}

# **** Kubernetes CLI ****

function kubeDeploymentVerification(){

    echo "************************************"
    echo " pods, deployments and configmaps details "
    echo "************************************"
    
    kubectl get pods -n $NAMESPACE
    kubectl get deployments -n $NAMESPACE
    kubectl get configmaps -n $NAMESPACE

}

function getKubeContainerLogs(){

    echo "************************************"
    echo " web-api log"
    echo "************************************"

    FIND=web-api
    WEBAPI_LOG=$(kubectl get pod -n $NAMESPACE | grep $FIND | awk '{print $1}')
    echo $WEBAPI_LOG
    kubectl logs $WEBAPI_LOG user-container

    echo "************************************"
    echo " articles logs"
    echo "************************************"

    FIND=articles
    ARTICLES_LOG=$(kubectl get pod -n $NAMESPACE | grep $FIND | awk '{print $1}')
    echo $ARTICLES_LOG
    kubectl logs $ARTICLES_LOG user-container

    echo "************************************"
    echo " web-app logs"
    echo "************************************"

    FIND=web-app-00002
    WEBAPP_LOG=$(kubectl get pod -n $NAMESPACE | grep $FIND | awk '{print $1}')
    echo $WEBAPP_LOG
    kubectl logs $WEBAPP_LOG user-container

}

function checkKubernetesPod (){
    application_pod="${1}" 

    array=("$application_pod")
    for i in "${array[@]}"
    do 
        echo ""
        echo "------------------------------------------------------------------------"
        echo "Check $i"
        while :
        do
            FIND=$i
            STATUS_CHECK=$(kubectl get pod -n $NAMESPACE | grep $FIND | awk '{print $3}')
            echo "Status: $STATUS_CHECK"
            if [ "$STATUS" = "$STATUS_CHECK" ]; then
                echo "$(date +'%F %H:%M:%S') Status: $FIND is Ready"
                echo "------------------------------------------------------------------------"
                break
            else
                echo "$(date +'%F %H:%M:%S') Status: $FIND($STATUS_CHECK)"
                echo "------------------------------------------------------------------------"
            fi
            sleep 5
        done
    done
}

# **********************************************************************************
# Execution
# **********************************************************************************

echo "************************************"
echo " CLI config"
echo "************************************"

setupCLIenvCE

echo "************************************"
echo " AppID creation"
echo "************************************"

createAppIDService

echo "************************************"
echo " AppID configuration"
echo "************************************"

configureAppIDInformation

echo "************************************"
echo " articles"
echo "************************************"

deployArticles
ibmcloud ce application events --application articles

echo "************************************"
echo " web-api"
echo "************************************"

deployWebAPI
ibmcloud ce application events --application web-api

echo "************************************"
echo " web-app"
echo "************************************"

deployWebApp
ibmcloud ce application events --application web-app

echo "************************************"
echo " AppID add redirect URI"
echo "************************************"

addRedirectURIAppIDInformation

echo "************************************"
echo " Verify deployments"
echo "************************************"

kubeDeploymentVerification

echo "************************************"
echo " Container logs"
echo "************************************"

getKubeContainerLogs

echo "************************************"
echo " URLs"
echo "************************************"
echo " - oAuthServerUrl   : $APPLICATION_OAUTHSERVERURL"
echo " - discoveryEndpoint: $APPLICATION_DISCOVERYENDPOINT"
echo " - Web-API          : $WEBAPI_URL"
echo " - Articles         : http://articles.$NAMESPACE.svc.cluster.local/articles"
echo " - Web-App          : $WEBAPP_URL"
