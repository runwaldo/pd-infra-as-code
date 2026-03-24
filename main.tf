# Create Escalation Policies
resource "pagerduty_escalation_policy" "this" {
  for_each = { for p in local.policy_data : p.name => p }
  name     = each.value.name
  num_loops = 2

  rule {
    escalation_delay_in_minutes = 30
    target { id = data.pagerduty_user.users[each.value.primary_contact].id }
  }

  rule {
    escalation_delay_in_minutes = 30
    target { id = data.pagerduty_user.users[each.value.secondary_contact].id }
  }
}

# Create Services & Auto-Link Slack
resource "pagerduty_service" "this" {
  for_each           = { for s in local.service_data : s.name => s }
  name               = each.value.name
  description        = each.value.description
  escalation_policy  = pagerduty_escalation_policy.this[each.value.escalation_policy].id
  alert_creation     = "create_alerts_and_incidents"
}

resource "pagerduty_slack_connection" "notification" {
  for_each     = { for s in local.service_data : s.name => s }
  source_id    = pagerduty_service.this[each.key].id
  source_type  = "service_reference"
  workspace_id = var.slack_workspace_id
  channel_id   = each.value.slack_channel
  
  notification_types = ["resolve", "acknowledge", "incident.triggered"]
}
