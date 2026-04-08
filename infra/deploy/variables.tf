variable "prefix" {
  description = "Prefix for resources in AWS"
  default     = "raa"
}

variable "project" {
  description = "Project name for tagging resources"
  default     = "devops-app-py"
}

variable "contact" {
  description = "Contact email for tagging resources"
  default     = "daniel.istrate@ymail.com"
}

variable "db_username" {
  description = "Username for the recipe app api database"
  default     = "pyapp"
}

variable "db_password" {
  description = "Password for the Terraform database"
  type        = string
  sensitive   = true
}