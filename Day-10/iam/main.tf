provider "aws" {
  region = "us-east-1"
}

# -----------------------------
# COUNT EXAMPLE
# -----------------------------

# count creates resources by index — aws_iam_user.count_users[0], [1], [2]
# Simple and readable but fragile when the list changes order.
# If you remove "mali" from position 0, Terraform renumbers everything:
# [0] becomes nana (was mali) → destroyed and recreated
# [1] becomes elorm (was nana) → destroyed and recreated
# One deletion causes two unexpected recreations.
resource "aws_iam_user" "count_users" {
  count = length(var.user_names_list)
  name  = "count-${var.user_names_list[count.index]}"
}

# -----------------------------
# FOR_EACH SET EXAMPLE
# -----------------------------

# for_each keys resources by value — aws_iam_user.set_users["mali"]
# Removing "mali" only deletes mali.
# Nana and elorm are completely untouched.
resource "aws_iam_user" "set_users" {
  for_each = var.user_names_set
  name     = "set-${each.value}"
}

# -----------------------------
# FOR_EACH MAP EXAMPLE
# -----------------------------

# for_each with a map gives you each.key (username) and each.value (object)
# This lets you carry additional configuration per resource.
# each.key   = "mali"
# each.value = { department = "engineering", admin = true }
resource "aws_iam_user" "map_users" {
  for_each = var.users
  name     = "map-${each.key}"

  tags = {
    Department = each.value.department
    Admin      = each.value.admin
  }
}