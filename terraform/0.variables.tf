# ---------------------------------------------------------------------------- #
# AWS Vars
# ---------------------------------------------------------------------------- #
variable "aws_vpc_cidr" {
  description = "value"
  type        = string
  default     = "10.10.0.0/16"
}
variable "aws_region" {
  description = "value"
  type        = string
}
variable "aws_route53_zone" {
  description = "value"
  type        = string
}
variable "aws_teleport_profile" {
  description = "value"
  type        = string
  default     = null
}
variable "aws_key_name" {
  description = "value"
  type        = string
  default     = "teleport-demo-oss"
}
variable "aws_tags" {
  description = "value"
  type        = map(any)
  default     = {}
}
# ---------------------------------------------------------------------------- #
# Teleport Vars
# ---------------------------------------------------------------------------- #
variable "teleport_cluster_name" {
  description = "value"
  type        = string
}
variable "teleport_version" {
  description = "value"
  type        = string
}
variable "teleport_email" {
  description = "value"
  type        = string
}

# ---------------------------------------------------------------------------- #
# GitHub SSO Variables
# ---------------------------------------------------------------------------- #
variable "gh_client_secret" {
  description = "value"
  type        = string
}
variable "gh_client_id" {
  description = "value"
  type        = string
}
variable "gh_org_name" {
  description = "value"
  type        = string
}
variable "gh_team_name" {
  description = "value"
  type        = string
}
