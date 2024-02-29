#!/bin/bash

set -e

# Load environment variables from .env file
if [ -f ".env" ]; then
    source ".env"
fi

az login --use-device-code -t $TENANT_ID
az account set --subscription $SUBSCRIPTION_ID