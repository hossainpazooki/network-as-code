# Violation: SEC-002-DRIFT - vpc_cidr default no longer matches the constant
# pinned in policy/security.rego (10.0.0.0/16).
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}
