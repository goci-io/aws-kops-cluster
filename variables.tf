
variable "stage" {
  type        = string
  default     = ""
  description = "The stage the cluster will be deployed for"
}

variable "namespace" {
  type        = string
  default     = ""
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

variable "kubernetes_version" {
  type        = string
  default     = "1.16.9"
  description = "The kubernetes version to deploy" 
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

variable "masters_instance_count" {
  type        = number
  default     = 5
  description = "Number of master nodes to create. Suggesting at least 5 to support failover of 2 masters"
}

variable "etcd_version" {
  type        = string
  default     = "3.2.24"
  description = "Version of etcd to use for kubernetes backend"
}

variable "etcd_events_storage_type" {
  type        = string
  default     = "gp2"
  description = "Storage type to use for the etcd events volume. If required you may use io1"
}

variable "etcd_events_storage_size" {
  type        = number
  default     = 64
  description = "Amount of Storage for event volumes"
}

variable "etcd_events_storage_iops" {
  type        = number
  default     = 0
  description = "Additional IOPS for event volumes"
}

variable "etcd_main_storage_type" {
  type        = string
  default     = "gp2"
  description = "Storage type to use for the etcd events volume"
}

variable "etcd_main_storage_size" {
  type        = number
  default     = 48
  description = "Amount of Storage for main volumes"
}

variable "etcd_main_storage_iops" {
  type        = number
  default     = 0
  description = "Additional IOPS for main volumes"
}

variable "masters_spot_enabled" {
  type        = bool
  default     = false
  description = "If set to true creates spot requests for master instances"
}

variable "masters_spot_on_demand" {
  type        = number
  default     = 2
  description = "Minimum on demand instances for masters to avoid service interruption when multiple spot instances go away at the same time"
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

variable "require_one_node" {
  type        = bool
  default     = false
  description = "If minSize of all worker instance group is set to 0 but at least one node is required. If you need one node in each AZ set minSize from one of your instance groups to 1"
}

variable "max_mutating_requests_in_flight" {
  type        = number
  default     = 800
  description = "Max requests in flight mutating API objects. Depends on the machine type and count for masters, as well as IOPS of etcd volumes"
}

variable "max_requests_in_flight" {
  type        = number
  default     = 2000
  description = "Max requests in flight reading API objects. Depends on the machine type and count for masters, as well as IOPS of etcd volumes"
}

variable "kops_addons" {
  type        = list(string)
  default     = []
  description = "Additional kops addons to include in the cluster manifest"
}

variable "enable_kops_validation" {
  type        = bool
  default     = true 
  description = "Useful if you want to wait for cluster to start up, deploy further things and then validate the clusters health. In that case set the validation to false"
}

variable "custom_s3_policies" {
  type        = list
  default     = []
  description = "Custom policies to attach to the kops s3 state bucket. You can specify readonly (true, Get* and List*), actions ([*]), resources (bucket) and principals" 
}

variable "secrets_path" {
  type        = string
  default     = "/secrets/tf"
  description = "Path to put CA and SSH keys into"
}

variable "ssh_access_cidrs" {
  type        = list(string)
  default     = [] 
  description = "Allowed CIDRs for SSH access"
}

variable "api_access_cidrs" {
  type        = list(string)
  default     = []
  description = "Allowed CIDRs to acces kubernetes master API"
}

variable "create_public_api_record" {
  type        = bool
  default     = false
  description = "Creates a public API record and grants 0.0.0.0/0 on the API LB security group. This is useful in scenarios where you want to use private dns but make the API server accessible using a public hosted zone"
}

variable "master_ips_for_private_dns" {
  type        = bool
  default     = true
  description = "If set to false will use the internal load balancer created by kops for internal master name. Otherwise masters will sync their IP addresses"
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

variable "additional_master_policies" {
  type        = string
  default     = ""
  description = "Additional policy documents to attach to the masters (Effect, Action, Resource policy as JSON list)"
}

variable "external_master_policies" {
  type        = list(string)
  default     = []
  description = "Additional policy ARNs to attach to the master role"
}

variable "bastion_public_name" {
  type        = string
  default     = "bastion"
  description = "Set to any subdomain name of your cluster dns to create a public dns entry for your bastion"
}

variable "acm_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a VPC module was installed. It must expose a certificate_arn"
}

variable "dns_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a DNS module was installed. It must expose a domain_name. If acm_module_state and certificate_arn are not set we try to get the certificate_arn from this module"
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

variable "public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of public subnet ids. Can be read from vpc remote state"
}

variable "private_subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of private subnet ids. Can be read from vpc remote state"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = "List of public subnet cidrs. Can be read from vpc remote state"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = "List of private subnet cidrs. Can be read from vpc remote state"
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

variable "openid_connect_enabled" {
  type        = bool
  default     = false
  description = "If set to true requires all other oidc_ prefixed variables to be set to configure OpenID connect on the Kubernetes API Server"
}

variable "oidc_issuer_url" {
  type        = string
  default     = ""
  description = "The issue URL of the OIDC token issuer"
}

variable "oidc_client_id" {
  type        = string
  default     = ""
  description = "The client ID for the API to use"
}

variable "oidc_username_claim" {
  type        = string
  default     = ""
  description = "The field representing the claim with username set"
}

variable "oidc_username_prefix" {
  type        = string
  default     = ""
  description = "A prefix to identify username claim (eg. oicd:)"
}

variable "oidc_groups_claim" {
  type        = string
  default     = ""
  description = "The field representing the claim with groups defined"
}

variable "oidc_groups_prefix" {
  type        = string
  default     = ""
  description = "A prefix to identify group claim (eg. oicd:)"
}

variable "oidc_ca_file" {
  type        = string
  default     = ""
  description = "Must be a path on the local file system containing the CA file"
}

variable "oidc_required_claims" {
  type        = list(object({ key = string, value = string}))
  default     = []
  description = "Required claims which must be set to allow access"
}
