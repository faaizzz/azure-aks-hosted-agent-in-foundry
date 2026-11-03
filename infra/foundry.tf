data "azurerm_client_config" "current" {}

# ---------------- Foundry project ----------------
resource "azurerm_cognitive_account_project" "this" {
  name                 = "travel-agents"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = azurerm_resource_group.this.location
  display_name         = "Travel agents"
  description          = "Project for the AKS-hosted travel agent (registered as an external agent)."

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# ---------------- Observability: Log Analytics + Application Insights ----------------
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1 # cost guard for the demo
  tags                = local.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = local.tags
}

# Connects Application Insights to the Foundry project (what "Tracing" in the portal reads from).
resource "azapi_resource" "project_appinsights_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-09-01"
  name      = "appinsights"
  parent_id = azurerm_cognitive_account_project.this.id

  body = {
    properties = {
      category = "AppInsights"
      target   = azurerm_application_insights.this.id
      authType = "ApiKey"
      credentials = {
        key = azurerm_application_insights.this.connection_string
      }
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_application_insights.this.id
      }
    }
  }

  schema_validation_enabled = false
}

# ---------------- Access for the person applying/operating this ----------------
# Needed to create the external-agent registration (data plane) and to view traces.
resource "azurerm_role_assignment" "operator_project_user" {
  scope                = azurerm_cognitive_account_project.this.id
  role_definition_name = "Foundry User" # formerly "Azure AI User"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "operator_openai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User" # also enables running the agent locally
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "operator_monitoring_reader" {
  scope                = azurerm_application_insights.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}
