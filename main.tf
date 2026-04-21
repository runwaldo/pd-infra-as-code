terraform {
  required_providers {
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.0"
    }
  }
}

provider "pagerduty" {
  token = var.pagerduty_token
}

# ==========================================
# 1. READ AND DEDUPLICATE THE CSV
# ==========================================
locals {
  raw_data = csvdecode(file("${path.module}/control_plane.csv"))

  teams = toset(distinct([for row in local.raw_data : row.team_name]))
  
  eps = { 
    for ep in distinct([for row in local.raw_data : row.ep_name]) : ep => {
      name  = ep
      team  = [for row in local.raw_data : row.team_name if row.ep_name == ep][0]
      users = distinct([for row in local.raw_data : row.user_email if row.ep_name == ep])
      tag   = [for row in local.raw_data : row.ep_tag if row.ep_name == ep][0]
    }
  }

  services = { 
    for obj in distinct([for row in local.raw_data : { name = row.service_name, ep = row.ep_name }]) : obj.name => obj 
  }

  memberships = { 
    for row in local.raw_data : "${row.team_name}-${row.user_email}" => {
      team  = row.team_name
      email = row.user_email
      role  = row.team_role
    }
  }

  emails = toset([for row in local.raw_data : row.user_email])

  tags = toset(distinct([for row in local.raw_data : row.ep_tag]))

  # FIXED: Deduplicate schedule names first to avoid "Duplicate object key" error
  schedules = { 
    for name in distinct([for row in local.raw_data : row.schedule_name if row.schedule_name != ""]) : name => {
      name  = name
      users = distinct([for r in local.raw_data : r.user_email if r.schedule_name == name])
    }
  }
}

# ==========================================
# 2. THE DATA LOOKUP 
# ==========================================
data "pagerduty_user" "lookup" {
  for_each = local.emails
  email    = each.value
}

# ==========================================
# 3. RESOURCE CREATION
# ==========================================

resource "pagerduty_team" "teams" {
  for_each = local.teams
  name     = each.key
}

resource "pagerduty_escalation_policy" "eps" {
  for_each = local.eps
  name     = each.value.name
  teams    = [pagerduty_team.teams[each.value.team].id]
  
  # GUARDRAIL: Forces destruction order to avoid API race conditions
  depends_on = [pagerduty_team_membership.memberships]
  
  rule {
    escalation_delay_in_minutes = 10
    
    dynamic "target" {
      for_each = each.value.users
      content {
        type = "user_reference"
        id   = data.pagerduty_user.lookup[target.value].id
      }
    }
  }
}

resource "pagerduty_service" "services" {
  for_each           = local.services
  name               = each.value.name
  escalation_policy  = pagerduty_escalation_policy.eps[each.value.ep].id
}

resource "pagerduty_team_membership" "memberships" {
  for_each = local.memberships
  
  user_id = data.pagerduty_user.lookup[each.value.email].id
  team_id = pagerduty_team.teams[each.value.team].id
  role    = each.value.role
}

# ==========================================
# 4. TAG MANAGEMENT
# ==========================================

resource "pagerduty_tag" "tags" {
  for_each = local.tags
  label    = each.key
}

resource "pagerduty_tag_assignment" "ep_tags" {
  for_each = local.eps

  tag_id      = pagerduty_tag.tags[each.value.tag].id
  entity_type = "escalation_policies"
  entity_id   = pagerduty_escalation_policy.eps[each.key].id
}

# ==========================================
# 5. SCHEDULE V2 MANAGEMENT
# ==========================================

resource "pagerduty_schedulev2" "v2_schedules" {
  for_each  = local.schedules
  name      = each.value.name
  
  # FIXED: V2 API requires full IANA time zone (e.g., "Etc/UTC")
  time_zone = "Etc/UTC" 
  
  # FIX: Explicitly setting the description bypasses the provider "Unknown Value" bug
  description = "Managed by Terraform" 

  rotation {
    event {
      name            = "Weekly Shift"
      start_time      = "2026-06-01T09:00:00Z"
      end_time        = "2026-06-08T09:00:00Z"
      effective_since = "2026-06-01T09:00:00Z"
      recurrence      = ["RRULE:FREQ=WEEKLY;BYDAY=MO"]

      assignment_strategy {
        type = "rotating_member_assignment_strategy"

        dynamic "member" {
          for_each = each.value.users
          content {
            type    = "user_member"
            user_id = data.pagerduty_user.lookup[member.value].id
          }
        }
      }
    }
  }
}