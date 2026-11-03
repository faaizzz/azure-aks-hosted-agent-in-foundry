output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "foundry_endpoint" {
  value = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com/"
}

output "model_deployment" {
  value = azurerm_cognitive_deployment.model.name
}

output "agent_identity_client_id" {
  value = azurerm_user_assigned_identity.agent.client_id
}

output "agent_image" {
  value = local.image
}

output "foundry_project_endpoint" {
  value = local.project_endpoint
}

output "app_insights_name" {
  value = azurerm_application_insights.this.name
}

output "external_agent" {
  value = {
    name          = local.external_agent_name
    otel_agent_id = local.otel_agent_id
  }
}
