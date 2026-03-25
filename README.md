# PagerDuty CSV Control Plane Demo

This repository demonstrates how to manage PagerDuty Teams, Escalation Policies, Services, and Memberships using a single, simple CSV file as your control plane.

## How it works
Terraform reads `control_plane.csv`, deduplicates the data, automatically looks up existing PagerDuty users by their email address, and builds the routing infrastructure dynamically.

## Prerequisites
1. You must have [Terraform installed](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
2. The users listed in the CSV **must already exist** in your PagerDuty account (e.g., provisioned via SSO/Okta).

## Quick Start

**1. Clone the repo:**
```bash
git clone https://github.com/runwaldo/pd-infra-as-code.git
cd pagerduty-csv-demo
