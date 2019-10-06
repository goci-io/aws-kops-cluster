
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

variable "delimiter" {
  type        = string
  default     = "-"
  description = "Delimiter to be used between `namespace`, `stage`, `name` and `attributes`"
}

variable "region" {
  type        = string
  description = "The own region identifier for this deployment"
}

variable "instance_groups" {
  type        = list
  description = "Instance groups to create. The masters are included by default. You will need to configure at least one additional node group"
}

variable "master_machine_type" {
  type        = string
  default     = "m5.large"
  description = "The AWS instance type to use for the masters"
}

variable "master_instance_count" {
  type        = number
  default     = 5
  description = "The count of master nodes to create. Suggested are at least 3, to support failover of 2 instances you will need at least 5"
}

variable "bastion_machine_type" {
  type        = string
  default     = "t2.micro"
  description = "The AWS instance type to use for the bastions"
}

variable "max_availability_zones" {
  type        = number
  default     = 3
  description = "Maximum availability zones to span with this cluster. We currently only support 3!!"
}

variable "ssh_path" {
  type        = string
  default     = "/secrets/tf/ssh"
  description = "Path to put SSH keys into"
}

variable "cluster_dns" {
  type        = string
  default     = ""
  description = "The DNS zone to use for the cluster if it differs from cluster name"
}

variable "cluster_dns_type" {
  type        = string
  default     = "Private"
  description = "The topology for the cluster dns zone (Private or Public)"
}

variable "tf_bucket" {
  type        = string
  default     = ""
  description = "The Bucket name to load remote state from"
}

variable "loadbalancer_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a LoadBalancer was installed. It must expose a loadbalancer_name OR loadbalancer_target_arn"
}

variable "master_loadbalancer_name" {
  type        = string
  default     = ""
  description = "The name of an existing load balancer to use for the kubernetes API if loadbalancer_module_state is not set"
}

variable "master_loadbalancer_target_arn" {
  type        = string
  default     = ""
  description = "The ARN of an existing target group to use for the kubernetes API if loadbalancer_module_state is not set"
}

variable "acm_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a VPC module was installed. It must expose a certificate_arn"
}

variable "dns_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a DNS module was installed. It must expose a domain_name and zone_id. If acm_module_state and certificate_arn are not set we try to get the certificate_arn from this module"
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "The ACM Certificate ARN to use if acm_module_state is not set"
}

variable "vpc_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a VPC module was installed. It must expose a vpc_id and public_ as well as private_subnet_ids"
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

variable "public_subnet_id_a" {
  type        = string
  default     = ""
  description = "The ID of the first public subnet"
}

variable "public_subnet_cidr_a" {
  type        = string
  default     = ""
  description = "The CIDR of the first public subnet"
}

variable "public_subnet_id_b" {
  type        = string
  default     = ""
  description = "The ID of the second public subnet"
}

variable "public_subnet_cidr_b" {
  type        = string
  default     = ""
  description = "The CIDR of the second public subnet"
}

variable "public_subnet_id_c" {
  type        = string
  default     = ""
  description = "The ID of the third public subnet"
}

variable "public_subnet_cidr_c" {
  type        = string
  default     = ""
  description = "The CIDR of the third public subnet"
}

variable "private_subnet_id_a" {
  type        = string
  default     = ""
  description = "The ID of the first private subnet"
}

variable "private_subnet_cidr_a" {
  type        = string
  default     = ""
  description = "The CIDR of the first private subnet"
}

variable "private_subnet_id_b" {
  type        = string
  default     = ""
  description = "The ID of the second private subnet"
}

variable "private_subnet_cidr_b" {
  type        = string
  default     = ""
  description = "The CIDR of the second private subnet"
}

variable "private_subnet_id_c" {
  type        = string
  default     = ""
  description = "The ID of the third private subnet"
}

variable "private_subnet_cidr_c" {
  type        = string
  default     = ""
  description = "The CIDR of the third private subnet"
}

variable "aws_region" {
  type        = string
  default     = ""
  description = "The AWS region the cluster will be deployed into if the target is not the current region"
}

variable "aws_account_id" {
  type        = string
  default     = ""
  description = "AWS Account ID. Defaults to current Account ID"
}

variable "aws_assume_role_arn" {
  type        = string
  default     = ""
  description = "The AWS Role ARN to assume to create resources"
}

# Workaround for https://github.com/terraform-providers/terraform-provider-aws/issues/8242
variable "external_account" {
  type        = bool
  default     = false
  description = "Whether kops is deployed into a different AWS account. Required to provide kops access to this account"
}

