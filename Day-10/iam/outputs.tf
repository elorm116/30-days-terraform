# -----------------------------
# COUNT OUTPUTS
# -----------------------------

# count resources are referenced as a list using [*]
output "count_user_arns" {
  description = "ARNs of all count-based IAM users"
  value       = aws_iam_user.count_users[*].arn
}

# -----------------------------
# FOR_EACH OUTPUTS
# -----------------------------

# for_each resources are referenced as a map
# Use a for expression to transform them into a clean name → ARN map
output "set_user_arns" {
  description = "Map of username to ARN for set-based users"
  value       = { for name, user in aws_iam_user.set_users : name => user.arn }
}

output "map_user_arns" {
  description = "Map of username to ARN for map-based users"
  value       = { for name, user in aws_iam_user.map_users : name => user.arn }
}

# -----------------------------
# FOR EXPRESSION — TRANSFORM EXAMPLE
# -----------------------------

# for expressions reshape data — they don't create resources
# This produces a list of uppercase usernames from the variable
output "uppercase_usernames" {
  description = "All usernames in uppercase — demonstrates for expression"
  value       = [for name in var.user_names_list : upper(name)]
}

# This produces a map of username → department from the map variable
output "user_departments" {
  description = "Map of username to department"
  value       = { for name, config in var.users : name => config.department }
}

# This filters to only admin users using an if clause in the for expression
output "admin_users" {
  description = "Only users where admin = true"
  value       = { for name, config in var.users : name => config.department if config.admin }
}