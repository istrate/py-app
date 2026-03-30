# Define default variable

variable "tf_state_bucket" {
  description = "Name of the S3 bucket of AWS for storing TF state"
  default     = "devops-py-app" # S3 buket name manually created in AWS
}

variable "tf_state_lock_table" {
  description = "Name of the DynamoDB table for TF state locking"
  default     = "devops-py-app-tf-lock" # DynamoDB table name manually created in AWS
}

variable "project" {
  description = "Project name for tagging resources"
  default     = "devops-py-app"
}

variable "contact" {
  description = "Contact name for tagging resources"
  default     = "daniel.istrate@ymail.com"
}