#!/bin/bash

set -e

resourceGroupLocation="swedencentral"
resourceGroupName="contoso-support-rg"
deploymentName="contoso-support"

function check_login {
    if [ -z "$(az account show)" ]; then
        echo "You are not logged in. Please run 'az login' or 'az login --use-device-code --tenant XXXXX' first."
        exit 1
    fi
}

function create_resource_group {
    echo "Creating resource group $resourceGroupName in $resourceGroupLocation..."
    az group create --name $resourceGroupName --location $resourceGroupLocation > /dev/null
}

function provision_resources {
    echo "Provisioning resources in resource group $resourceGroupName..."
    az deployment group create --resource-group $resourceGroupName --name $deploymentName --only-show-errors --template-file main.bicep > /dev/null
}

function setup_environment_variables {
    echo "Setting up environment variables in .env file..."
    # Save output values to variables
    openAiService=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.openai_name.value -o tsv)
    searchService=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.search_name.value -o tsv)
    cosmosService=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.cosmos_name.value -o tsv)
    searchEndpoint=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.search_endpoint.value -o tsv)
    openAiEndpoint=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.openai_endpoint.value -o tsv)
    cosmosEndpoint=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.cosmos_endpoint.value -o tsv)
    mlProjectName=$(az deployment group show --name $deploymentName --resource-group $resourceGroupName --query properties.outputs.mlproject_name.value -o tsv)

    # Get keys from services
    searchKey=$(az search admin-key show --service-name $searchService --resource-group $resourceGroupName --query primaryKey --output tsv)
    apiKey=$(az cognitiveservices account keys list --name $openAiService --resource-group $resourceGroupName --query key1 --output tsv)
    cosmosKey=$(az cosmosdb keys list --name $cosmosService --resource-group $resourceGroupName --query primaryMasterKey --output tsv)

    # Write environment variables to .env file
    echo "" > ../.env
    echo "CONTOSO_SEARCH_ENDPOINT=$searchEndpoint" >> ../.env
    echo "CONTOSO_SEARCH_KEY=$searchKey" >> ../.env
    echo "CONTOSO_INDEX_NAME=contoso-manuals-chunked" >> ../.env
    echo " " >> ../.env
    echo "CONTOSO_AI_SERVICES_ENDPOINT=$openAiEndpoint" >> ../.env
    echo "CONTOSO_AI_SERVICES_KEY=$apiKey" >> ../.env
    echo "CONTOSO_AI_SERVICES_VERSION=2023-07-01-preview" >> ../.env
    echo " " >> ../.env    
    echo "COSMOS_ENDPOINT=$cosmosEndpoint" >> ../.env
    echo "COSMOS_KEY=$cosmosKey" >> ../.env
    echo " " >> ../.env
    echo "AZURE_OPENAI_EMBEDDING_DEPLOYMENT=text-embedding-ada-002" >> ../.env  
}

function write_config_json {
    echo "Writing config.json file for PromptFlow usage..."
    subscriptionId=$(az account show --query id -o tsv)
    echo "{\"subscription_id\": \"$subscriptionId\", \"resource_group\": \"$resourceGroupName\", \"workspace_name\": \"$mlProjectName\"}" > ../config.json
}

check_login
create_resource_group
provision_resources
setup_environment_variables
write_config_json

echo "Provisioning complete!"