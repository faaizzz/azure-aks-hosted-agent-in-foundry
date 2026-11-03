variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "name_prefix" {
  type    = string
  default = "travelagent"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "model_name" {
  type    = string
  default = "gpt-5-mini"
}

variable "model_version" {
  type    = string
  default = "2025-08-07"
}

variable "model_capacity" {
  type        = number
  default     = 10
  description = "Capacity in thousands of tokens per minute (GlobalStandard)."
}

variable "k8s_namespace" {
  type    = string
  default = "travel"
}

variable "k8s_service_account" {
  type    = string
  default = "travel-agent"
}

variable "openai_api_version" {
  type    = string
  default = "2025-04-01-preview"
}
