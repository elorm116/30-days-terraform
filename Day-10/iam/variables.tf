# Used for count example — a simple list
variable "user_names_list" {
  description = "List of IAM usernames — used to demonstrate count"
  type        = list(string)
  default     = ["mali", "nana", "elorm"]
}

# Used for for_each set example — order doesn't matter
variable "user_names_set" {
  description = "Set of IAM usernames — used to demonstrate for_each"
  type        = set(string)
  default     = ["mali", "nana", "elorm"]
}

# Used for for_each map example — carries additional config per user
variable "users" {
  description = "Map of IAM users with department and admin flag"
  type = map(object({
    department = string
    admin      = bool
  }))
  default = {
    mali = { department = "engineering", admin = true }
    nana   = { department = "marketing",   admin = false }
    elorm = { department = "devops",    admin = true }
  }
}