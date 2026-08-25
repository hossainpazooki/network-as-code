# Conforming: vpc_cidr default matches the constant pinned in
# policy/security.rego (SEC-002-DRIFT must stay silent here).
# Mirrors fixtures/historical/terraform/variables.tf:146.
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
