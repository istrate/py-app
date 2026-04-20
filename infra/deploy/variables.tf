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

variable "ecr_proxy_image" {
  description = "Path to the ECR repo with the proxy image"
}

variable "ecr_app_image" {
  description = "Path to the ECR repo with the API image"
}

variable "django_secret_key" {
  description = "Secret key for Django"
}