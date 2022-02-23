param prefix string = 'mfquiz'

var appInsightsName = '${prefix}-appinsights'
var appPlanName = '${prefix}-appplan'
var appName = '${prefix}-webapp'
var logAnalyticsName = '${prefix}loganalytics'
var signalRName = '${prefix}signalr'
var containerName = 'quizassets'
var questionSetTableName = 'questionsets'
param storageAccountName string = '${prefix}store${uniqueString(resourceGroup().id)}'

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageAccountType string = 'Standard_LRS'

// Log Analytics workspace

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: logAnalyticsName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}


// App Insights

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appPlanName
  location: resourceGroup().location
  sku: {
    name: 'S1'
    tier: 'Standard'
    capacity: 1
  }
  kind: 'app'
}


//App Service
resource webApplication 'Microsoft.Web/sites@2018-11-01' = {
  name: appName
  location: resourceGroup().location
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }
  properties: {
    serverFarmId: appServicePlan.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}



resource appSettings 'Microsoft.Web/sites/config@2021-02-01' = {
  name: 'appsettings'
  parent: webApplication
  properties: {
    'APPINSIGHTS_INSTRUMENTATIONKEY': appInsights.properties.InstrumentationKey
    'APPLICATIONINSIGHTS_CONNECTION_STRING' : 'InstrumentationKey=${appInsights.properties.InstrumentationKey};IngestionEndpoint=https://uksouth-1.in.applicationinsights.azure.com/'
    'ApplicationInsightsAgent_EXTENSION_VERSION': '~3'
    'XDT_MicrosoftApplicationInsights_Mode':'Recommended'
    'Azure:SignalR:ConnectionString':'Endpoint=https://${signalR.properties.hostName};AuthType=aad;Version=1.0;'
    'Azure:Storage:ConnectionString':'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id,storageAccount.apiVersion).keys[0].value}'
    'QuizAssetsContainerName':'quizassets'
  }
}


// Add SignalR Service
resource signalR 'Microsoft.SignalRService/signalR@2021-09-01-preview' = {
  name: signalRName
  location: resourceGroup().location
  sku: {
    name: 'Standard_S1'
    tier: 'Standard'
    capacity: 1
  }
  kind: 'SignalR'
  properties: {
    tls: {
      clientCertEnabled: false
    }
    features: [
      {
        flag: 'ServiceMode'
        value: 'Default'
      }
      {
        flag: 'EnableConnectivityLogs'
        value: 'True'
      }
    ]
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {}
}

resource blobservices 'Microsoft.Storage/storageAccounts/blobServices@2021-08-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    cors: {
      corsRules: [
      ]
    }
  }
}

resource tableservices 'Microsoft.Storage/storageAccounts/tableServices@2021-08-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    cors: {
      corsRules: [
      ]
    }
  }
}

resource storageAssetsContainer 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-08-01' = {
  name: questionSetTableName
  parent: tableservices
}

output webApplicationPrincipalId string = webApplication.identity.principalId

