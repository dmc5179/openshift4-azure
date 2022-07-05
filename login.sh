#!/bin/bash -xe

#usgovtexas (US Gov Texas)
#usgovvirginia (US Gov Virginia)

#az login
#az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az account set --subscription "Azure subscription 1"
az account show

#homeTenantId 9e4789ac-343d-499c-9991-809c995d1dcb
OCP_TENANT_ID=$(az account show --query tenantId -o tsv)
echo $OCP_TENANT_ID

#id: db940a9e-78f4-4739-8e15-cfe15c7bb7d6
OCP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo $OCP_SUBSCRIPTION_ID

SUBSCRIPTION_CODE=mct
PREFIX=$SUBSCRIPTION_CODE-ocp-dev
echo $PREFIX
OCP_SP=$(az ad sp create-for-rbac --role Contributor --name "${PREFIX}-installer-sp" --scopes "/subscriptions/${OCP_SUBSCRIPTION_ID}")


echo $OCP_SP
echo $OCP_SP | jq
OCP_SP_ID=$(echo $OCP_SP | jq -r .appId)
OCP_SP_PASSWORD=$(echo $OCP_SP | jq -r .password)
OCP_SP_TENANT=$(echo $OCP_SP | jq -r .tenant)
OCP_SP_SUBSCRIPTION_ID=$OCP_SUBSCRIPTION_ID
echo $OCP_SP_ID
echo $OCP_SP_PASSWORD
echo $OCP_SP_TENANT
echo $OCP_SP_SUBSCRIPTION_ID

export AZURE_SUBSCRIPTION_ID=$OCP_SP_SUBSCRIPTION_ID
export AZURE_TENANT=$OCP_SP_TENANT
export AZURE_CLIENT_ID=$OCP_SP_ID
export AZURE_SECRET=$OCP_SP_PASSWORD

# to assign the User Access Administrator role, run the following command:
az role assignment create --role "User Access Administrator" \
    --assignee-object-id $(az ad sp list --filter "appId eq '${AZURE_CLIENT_ID}'" \
       | jq '.[0].id' -r)

# to assign the Azure Active Directory Graph permission, run the following command:
az ad app permission add --id ${AZURE_CLIENT_ID} --api 00000002-0000-0000-c000-000000000000 \
	--api-permissions 824c81eb-e3f8-4ee6-8f6d-de7f50d565b7=Role

# Requesting the (Admin Consent) for the permission.
az ad app permission grant --id ${AZURE_CLIENT_ID} --api 00000002-0000-0000-c000-000000000000 --scope 
# Now by visiting the AAD in Azure portal, you can search for your service principal under "App Registrations" and make sure to grant the admin consent.

# Assigning "Contributor" (for Azure resources creation) and "User Access Administrator" (to grant access to OCP provisioned components)
az role assignment create --assignee ${AZURE_CLIENT_ID} --role "Contributor"
az role assignment create --assignee ${AZURE_CLIENT_ID} --role "User Access Administrator"

# Have a look at SP Azure assignments:
az role assignment list --assignee ${AZURE_CLIENT_ID} -o table

# Saving the SP credentials so the OCP installer will pick the new one without prompting
echo $OCP_SP | jq --arg sub_id $OCP_SUBSCRIPTION_ID '{subscriptionId:$sub_id,clientId:.appId, clientSecret:.password,tenantId:.tenant}' > ~/.azure/osServicePrincipal.json
