locals {
  service_data = csvdecode(file("${path.module}/config/services.csv"))
  policy_data  = csvdecode(file("${path.module}/config/policies.csv"))

  # Gather all unique emails for a single batch lookup
  emails = distinct(concat(
    [for p in local.policy_data : p.primary_contact],
    [for p in local.policy_data : p.secondary_contact]
  ))
}

data "pagerduty_user" "users" {
  for_each = toset(local.emails)
  email    = each.value
}
