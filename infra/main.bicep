targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed([
  'australiaeast'
  'eastasia'
  'eastus'
  'eastus2'
  'northeurope'
  'southcentralus'
  'southeastasia'
  'swedencentral'
  'uksouth'
  'westus2'
  'eastus2euap'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param resourceGroupName string = ''

// MCP Client APIM gateway specific variables
var abbrs = loadJsonContent('./abbreviations.json')
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

var apimResourceToken = toLower(uniqueString(subscription().id, resourceGroupName, environmentName, location))
var apiManagementName = '${abbrs.apiManagementService}${apimResourceToken}'

// apim service deployment
module apimService './core/apim/apim.bicep' = {
  name: apiManagementName
  scope: rg
  params: {
    apiManagementName: apiManagementName
  }
}

// Fetch Asana client ID using a deployment script
module dynamicClientRegisterationDeploymentScript 'app/dynamic-client-registeration/register-dynamic-client-script.bicep' ={
  name: 'fetch-asana-client-id'
  scope: rg
  params: {
    apimServiceName: apiManagementName
  }
}


// MCP Asana API with endpoints and operations
module mcpAsanaAPIModule 'app/apim-mcp/asana-mcp-api.bicep' = {
  name: 'mcpAsanaApi'
  scope: rg
  params: {
    asanaClientId: dynamicClientRegisterationDeploymentScript.outputs.asanaClientId
    apimServiceName: apimService.name
    apimSystemAssignedIdentityPrincipalId: apimService.outputs.apimSystemAssignedIdentityPrincipalId
    apimSystemAssignedIdentityTenantId: apimService.outputs.apimSystemAssignedIdentityTenantId
    APIServiceURL: 'https://mcp.asana.com'
  }
}

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_ENDPOINTS array = ['${apimService.outputs.apimResourceGatewayURL}/mcp/sse']
