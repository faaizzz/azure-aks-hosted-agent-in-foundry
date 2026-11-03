locals {
  agent_dir = "${path.module}/../agent"
  agent_files = sort(setunion(
    fileset(local.agent_dir, "app/**"),
    ["Dockerfile", "requirements.txt"],
  ))
  # Content hash of the agent source; used as the image tag so code changes roll out on apply.
  agent_hash = substr(sha256(join("", [for f in local.agent_files : filesha256("${local.agent_dir}/${f}")])), 0, 12)
  image      = "${azurerm_container_registry.this.login_server}/travel-agent:${local.agent_hash}"
}

# Builds in ACR (linux/amd64, matches the B2s node) as part of terraform apply.
resource "terraform_data" "image_build" {
  triggers_replace = [local.agent_hash, azurerm_container_registry.this.id]

  provisioner "local-exec" {
    command = "az acr build --registry ${azurerm_container_registry.this.name} --subscription ${var.subscription_id} --image travel-agent:${local.agent_hash} --platform linux/amd64 ${local.agent_dir}"
  }
}
