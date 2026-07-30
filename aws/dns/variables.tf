variable "zone_name" {
  description = "Fully-qualified name of the Route53 hosted zone (e.g. \"prod.example.com\"). Used to create the zone when existing_zone_id is null, and to look it up otherwise."
  type        = string
}

variable "existing_zone_id" {
  description = "ID of an existing Route53 hosted zone to reuse. When null (default) the module creates and manages the zone named zone_name. When set, the module reuses that zone and creates no zone resource."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Certificate
//---------------------------------------------------------------------

variable "certificate_domain_name" {
  description = "Primary domain name for the ACM certificate (e.g. \"*.prod.example.com\"). Must fall within the hosted zone so DNS validation records can be created."
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domains (SANs) to include on the certificate. Each must fall within the hosted zone."
  type        = list(string)
  default     = []
}

variable "wait_for_validation" {
  description = "Whether to block (via aws_acm_certificate_validation) until the certificate is issued. Set false to create the validation records without waiting — useful when the zone's name servers are not yet delegated."
  type        = bool
  default     = true
}

variable "validation_record_ttl" {
  description = "TTL in seconds for the ACM DNS validation records."
  type        = number
  default     = 60
}

//---------------------------------------------------------------------
// Alias records
//---------------------------------------------------------------------

variable "alias_records" {
  description = "Map of record name => alias target. Creates A-record aliases in the zone pointing at AWS resources such as an ALB. Key is the record FQDN; value carries the target DNS name and hosted zone ID (e.g. an ALB's dns_name and zone_id)."
  type = map(object({
    target_dns_name        = string
    target_zone_id         = string
    evaluate_target_health = optional(bool, false)
  }))
  default = {}
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
