locals {
  external_agent_name = "travel-planner-agent"
  otel_agent_id       = "travel-planner-agent-v1"
  project_endpoint    = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.services.ai.azure.com/api/projects/${azurerm_cognitive_account_project.this.name}"
  register_script     = abspath("${path.module}/../scripts/register_external_agent.py")
  register_cmd        = "uv run --quiet --with 'azure-ai-projects>=2.3.0' --with azure-identity python ${local.register_script}"
}

# Foundry external-agent registration is a preview data-plane API with no Terraform/ARM resource,
# so it is applied from Terraform via the SDK (same pattern as the ACR image build).
resource "terraform_data" "register_external_agent" {
  triggers_replace = [
    local.project_endpoint,
    local.external_agent_name,
    local.otel_agent_id,
    filesha256(local.register_script),
  ]

  # Values for the destroy-time provisioner (it can only reference self).
  input = {
    endpoint = local.project_endpoint
    name     = local.external_agent_name
    otel_id  = local.otel_agent_id
    cmd      = local.register_cmd
  }

  provisioner "local-exec" {
    command = "${local.register_cmd} create"
    environment = {
      FOUNDRY_PROJECT_ENDPOINT = local.project_endpoint
      AGENT_NAME               = local.external_agent_name
      OTEL_AGENT_ID            = local.otel_agent_id
      AGENT_DESCRIPTION        = "LangGraph travel planner running on AKS (external agent)."
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${self.input.cmd} delete"
    environment = {
      FOUNDRY_PROJECT_ENDPOINT = self.input.endpoint
      AGENT_NAME               = self.input.name
      OTEL_AGENT_ID            = self.input.otel_id
    }
  }

  depends_on = [
    azapi_resource.project_appinsights_connection,
    azurerm_role_assignment.operator_project_user,
    kubernetes_deployment_v1.agent,
  ]
}
