terraform {
  required_providers {
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.0"
    }
  }
}

provider "pagerduty" {
  oauth_token = var.pagerduty_oauth_token
}

# ==========================================
# 1. READ AND DEDUPLICATE THE CSV
# ==========================================
locals {
  raw_data = csvdecode(file("${path.module}/control_plane.csv"))

  teams = toset(distinct([for row in local.raw_data : row.team_name]))
  
  # UPDATED: We now group all user emails that belong to the same EP
  eps = { 
    for ep in distinct([for row in local.raw_data : row.ep_name]) : ep => {
      name  = ep
      team  = [for row in local.raw_data : row.team_name if row.ep_name == ep][0]
      users = distinct([for row in local.raw_data : row.user_email if row.ep_name == ep])
    }
  }

  services = { 
    for obj in distinct([for row in local.raw_data : { name = row.service_name, ep = row.ep_name }]) : 
    obj.name => obj 
  }

  memberships = { 
    for row in local.raw_data : "${row.team_name}-${row.user_email}" => {
      team  = row.team_name
      email = row.user_email
      role  = row.team_role
    }
  }

  emails = toset([for row in local.raw_data : row.user_email])
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

# UPDATED: Uses a dynamic block to target the specific users 
resource "pagerduty_escalation_policy" "eps" {
  for_each = local.eps
  name     = each.value.name
  teams    = [pagerduty_team.teams[each.value.team].id]
  
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