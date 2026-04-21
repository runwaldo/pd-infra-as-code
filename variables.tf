variable "pagerduty_token" {
  description = "PagerDuty API token"
  type        = string
  sensitive   = true
}

#variable "pagerduty_client_id" {
#  type        = string
#  description = "PagerDuty OAuth Client ID"
#}

#variable "pagerduty_client_secret" {
#  type        = string
#  description = "PagerDuty OAuth Client Secret"
#  sensitive   = true
#}

#variable "pagerduty_service_region" {
#  type        = string
#  description = "PagerDuty service region"
#  default     = "us" # Default US region. Supported value: eu. 
#}

#variable "pagerduty_subdomain" {
#  type        = string
#  description = "PagerDuty subdomain"
#}