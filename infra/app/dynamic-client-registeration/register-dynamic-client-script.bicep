@description('The name of the API Management service')
param apimServiceName string

// This Bicep file registers a dynamic client with Asana using a deployment script.
resource dynamicClientRegisterationDeploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'fetch-asana-client-id'
  location: resourceGroup().location
  tags: {}
  kind: 'AzurePowerShell'
  properties: {
    environmentVariables: [
      {
        name: 'APIM_NAME'
        value: apimServiceName
      }
    ]
    azPowerShellVersion: '10.0'
    scriptContent: '''
      # Define the request body
      $payload = @{
        redirect_uris = @("https://authorization-manager.consent.azure-apim.net/redirect/apim/$($env:APIM_NAME)")
        token_endpoint_auth_method = "none"
        grant_types = @("authorization_code", "refresh_token")
        response_types = @("code")
        client_name = "MCP Inspector"
        client_uri = "https://authorization-manager.consent.azure-apim.net"
      } | ConvertTo-Json -Depth 10

      # Make the API request
      $response = Invoke-RestMethod -Uri "https://mcp.asana.com/register" `
                                    -Method Post `
                                    -Body $payload `
                                    -ContentType "application/json"

      $clientId = $response.client_id  # Assuming response contains client_id

      Write-Output "{ `"clientId`": `"$clientId`" }"
      # setting the clientId in outputs object on the script to reference later
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs["clientId"] = $clientId
    
    ''' // or primaryScriptUri: 'https://raw.githubusercontent.com/Azure/azure-docs-bicep-samples/main/samples/deployment-script/inlineScript.ps1'
    timeout: 'P1D'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: '1'
  }
}

output result object = dynamicClientRegisterationDeploymentScript.properties.outputs
output asanaClientId string = dynamicClientRegisterationDeploymentScript.properties.outputs.clientId
