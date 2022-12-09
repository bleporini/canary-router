variable "confluent_cloud_api_key" {
  description = "Cloud API key"
  type        = string
  default     = ""
}

variable "confluent_cloud_api_secret" {
  description = "Cloud API secret"
  type        = string
  default     = ""
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "qatarcentral"
}

variable "sr_region" {
  description = "Cloud region"
  type        = string
  default     = "sgreg-9"
}

variable "cloud" {
  description = "Cloud provider"
  type        = string
  default     = "AZURE"
}


