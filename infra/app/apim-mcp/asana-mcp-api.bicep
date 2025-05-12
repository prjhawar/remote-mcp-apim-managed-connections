
@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param apimServiceName string

@description('The system-assigned managed identity for the API Management instance.')
param apimSystemAssignedIdentityPrincipalId string

@description('The system-assigned managed identity for the API Management instance.')
param apimSystemAssignedIdentityTenantId string

@description('The API service URL.')
param APIServiceURL string

@description('The client ID for the Asana API.')
param asanaClientId string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource mcpAsanaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'mcp-asana-api'
  properties: {
    displayName: 'Asana MCP'
    description: 'Asana MCP endpoint to be used by the Asana API'
    apiRevision: '1'
    subscriptionRequired: false
    serviceUrl: APIServiceURL
    path: ''
    protocols: [
      'https'
    ]
  }
}

// Apply policy at the API level for all operations
resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: mcpAsanaApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('asana-mcp-api.policy.xml')
  }
}

// Create the SSE endpoint operation
resource mcpSseOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpAsanaApi
  name: 'mcp-sse'
  properties: {
    displayName: 'MCP SSE Endpoint'
    method: 'GET'
    urlTemplate: '/sse'
    description: 'Server-Sent Events endpoint for MCP Server'
  }
}

// Create the message endpoint operation
resource mcpMessageOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpAsanaApi
  name: 'mcp-message'
  properties: {
    displayName: 'MCP Message Endpoint'
    method: 'POST'
    urlTemplate: '/sse/message'
    description: 'Message endpoint for MCP Server'
  }
}

// Create the authorization provider for Asana MCP
resource mcpAsanaAuthorizationProvider 'Microsoft.ApiManagement/service/authorizationProviders@2024-06-01-preview' = {
  parent: apim
  name: 'asana-mcp-authProvider'
  properties: {
    displayName: 'asana-mcp-authProvider'
    identityProvider: 'oauth2pkce'
    oauth2: {
      redirectUrl: 'https://authorization-manager.consent.azure-apim.net/redirect/apim/${apim.name}'
      grantTypes: {
        authorizationCode: {
          clientId: asanaClientId
          authorizationUrl: 'https://mcp.asana.com/authorize'
          tokenUrl: 'https://mcp.asana.com/token'
          refreshUrl: 'https://mcp.asana.com/token'
          clientSecret: 'unused'
        }
      }
    }
  }
}

// Create an Authorization for Asana MCP
resource mcpAsanaAuthorization 'Microsoft.ApiManagement/service/authorizationProviders/authorizations@2024-06-01-preview' = {
  parent: mcpAsanaAuthorizationProvider
  name: 'asana-mcp-authorization'
  properties: {
    authorizationType: 'oauth2'
    oauth2grantType: 'authorizationCode'
  }
}

// Create an Access policy for Asana MCP Authorization
resource mcpAsanaAuthorizationAccessPolicy 'Microsoft.ApiManagement/service/authorizationProviders/authorizations/accessPolicies@2024-06-01-preview' = {
  parent: mcpAsanaAuthorization
  name: 'asana-mcp-authorization-accessPolicy'
  properties: {
    objectId: apimSystemAssignedIdentityPrincipalId
    tenantId: apimSystemAssignedIdentityTenantId
  }
}

resource AsanaAuthorizationProvider 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apim
  name: 'McpAsanaAuthorizationProvider'
  properties: {
    displayName: 'McpAsanaAuthorizationProvider'
    value: mcpAsanaAuthorizationProvider.name
    secret: false
  }
}

resource AsanaAuthorization 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apim
  name: 'McpAsanaAuthorization'
  properties: {
    displayName: 'McpAsanaAuthorization'
    value: mcpAsanaAuthorization.name
    secret: false
  }
}

// Output the API ID for reference
output apiId string = mcpAsanaApi.id
