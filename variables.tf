variable "db_username" {
  default = "admin"
}

variable "db_password" {
  default     = "HorizonTechX123!"   # ← Change this!
  sensitive   = true
}
variable "key_pair_name" {
  description = "ravi(linux).pem"  
  default     = "ravi(linux)"   # ← paste the name from above command
}
