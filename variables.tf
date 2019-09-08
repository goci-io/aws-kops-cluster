
variable "stage" {
  type        = string
  description = "The stage the cluster will be deployed for"
}

variable "namespace" {
  type        = string
  description = "Namespace the cluster belongs to"
}

variable "attributes" {
  type        = list
  default     = []
  description = "Additional attributes (e.g. `eu1`)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. map(`BusinessUnit`,`XYZ`)"
}

variable "root_domain" {
  type        = string
  description = "Root domain to use to build the cluster name and dns zone"
}

variable "vpc_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a VPC module was installed. It must expose a vpc_id and public_ as well as private_subnet_ids"
}

variable "acm_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a VPC module was installed. It must expose a certificate_arn"
}

variable "tf_bucket" {
  type        = string
  default     = ""
  description = "The Bucket name to load remote state from"
}

variable "instance_groups" {
  type = map(object({
    type                       = string
    name                       = string
    image                      = string
    count_min                  = number
    count_max                  = number
    autospotting               = bool
    autospotting_min_on_demand = number
    node_role                  = string
    storage_in_gb              = number
  }))
}

variable "master_storage_in_gb" {
  default     = 56
  description = "Amount of storage for masters in GB"
}

variable "ssh_keys" {
  type        = list(string)
  default     = ["kops"]
  description = "List of SSH Key names to create and grant access via bastions"
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "The VPC ID to use if vpc_module_state is not set"
}

variable "vpc_cidr" {
  type        = string
  default     = ""
  description = "The VPC CIDR to use if vpc_module_state is not set"
}

