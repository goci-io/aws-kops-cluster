
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

variable "kubernetes_version" {
  type        = string
  default     = "1.15.7"
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

variable "create_api_loadbalancer" {
  type        = bool
  default     = true
  description = "Creates an AWS Load Balancer infront of masters and API Server."  
}

variable "api_loadbalancer_type" {
  type        = string
  default     = "application"
  description = "Load balancer type to deploy as additional public load balancer when a private zone uses master ips but API server should be publicly accessible"  
}

variable "master_ips_for_private_api_dns" {
  type        = bool
  default     = false
  description = "When there is a private hosted zone the api DNS record can point directly to the master IPs of the associated VPC"
}

variable "bastion_public_name" {
  type        = string
  default     = ""
  description = "Set to any subdomain name of your cluster dns to create a public dns entry for your bastion"
}

variable "api_cert_module_state" {
  type        = string
  default     = ""
  description = "The key or path to the state where a custom certificate was installed. It must expose a certificate_private_key, certificate_chain and certificate_body" 
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

