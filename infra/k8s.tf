resource "kubernetes_namespace_v1" "travel" {
  metadata {
    name = var.k8s_namespace
  }
}

resource "kubernetes_service_account_v1" "agent" {
  metadata {
    name      = var.k8s_service_account
    namespace = kubernetes_namespace_v1.travel.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.agent.client_id
    }
  }
}

resource "kubernetes_secret_v1" "telemetry" {
  metadata {
    name      = "agent-telemetry"
    namespace = kubernetes_namespace_v1.travel.metadata[0].name
  }
  data = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.this.connection_string
  }
}

resource "kubernetes_deployment_v1" "agent" {
  metadata {
    name      = "travel-agent"
    namespace = kubernetes_namespace_v1.travel.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "travel-agent" }
    }

    template {
      metadata {
        labels = {
          app                           = "travel-agent"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.agent.metadata[0].name

        container {
          name  = "agent"
          image = local.image

          port {
            container_port = 8000
          }

          env {
            name  = "AZURE_OPENAI_ENDPOINT"
            value = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com/"
          }
          env {
            name  = "AZURE_OPENAI_DEPLOYMENT"
            value = azurerm_cognitive_deployment.model.name
          }
          env {
            name  = "AZURE_OPENAI_API_VERSION"
            value = var.openai_api_version
          }

          env {
            name  = "AGENT_NAME"
            value = local.external_agent_name
          }
          env {
            name  = "OTEL_AGENT_ID"
            value = local.otel_agent_id
          }
          env {
            name = "APPLICATIONINSIGHTS_CONNECTION_STRING"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.telemetry.metadata[0].name
                key  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
              }
            }
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8000
            }
            initial_delay_seconds = 5
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8000
            }
            initial_delay_seconds = 15
          }
        }
      }
    }
  }

  wait_for_rollout = true

  depends_on = [
    terraform_data.image_build,
    azurerm_role_assignment.aks_acr_pull,
    azurerm_role_assignment.agent_openai_user,
    azurerm_federated_identity_credential.agent,
  ]
}

resource "kubernetes_service_v1" "agent" {
  metadata {
    name      = "travel-agent"
    namespace = kubernetes_namespace_v1.travel.metadata[0].name
  }

  spec {
    selector = { app = "travel-agent" }
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = 8000
    }
  }
}
