locals {
  require_one_worker_node = var.require_one_node && local.worker_node_min_count == 0
  worker_node_min_count = length(flatten([
    for e in var.instance_groups.*.count_min : range(e)
  ]))
}

# Deploy seperate IGs per AWS Availability Zone
# This usually helps the cluster autoscaler 
data "null_data_source" "instance_groups" {
  count = length(var.instance_groups) * var.max_availability_zones

  inputs = {
    name = format(
      "%s-%s",
      lookup(var.instance_groups[floor(count.index / 3)], "name"),
      element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)
    )

    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_dns            = local.cluster_dns
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      node_role              = "Node"
      public_ip              = false
      autoscaler             = true
      image                  = lookup(var.instance_groups[floor(count.index / 3)], "image", "")
      instance_name          = lookup(var.instance_groups[floor(count.index / 3)], "name")
      instance_type          = lookup(var.instance_groups[floor(count.index / 3)], "instance_type")
      instance_max           = lookup(var.instance_groups[floor(count.index / 3)], "count_max", 5)
      instance_min           = local.require_one_worker_node && count.index == 0 ? 1 : lookup(var.instance_groups[floor(count.index / 3)], "count_min", 1)
      external_lb_name       = lookup(var.instance_groups[floor(count.index / 3)], "loadbalancer_name", "")
      external_target_arn    = lookup(var.instance_groups[floor(count.index / 3)], "loadbalancer_target_arn", "")
      storage_type           = lookup(var.instance_groups[floor(count.index / 3)], "storage_type", "gp2")
      storage_iops           = lookup(var.instance_groups[floor(count.index / 3)], "storage_iops", 0)
      storage_in_gb          = lookup(var.instance_groups[floor(count.index / 3)], "storage_in_gb", 32)
      security_group         = lookup(var.instance_groups[floor(count.index / 3)], "security_group", "")
      subnet_type            = lookup(var.instance_groups[floor(count.index / 3)], "subnet", "private")
      subnet_ids             = [element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)]
      autospotting_enabled   = lookup(var.instance_groups[floor(count.index / 3)], "autospotting_enabled", true)
      autospotting_on_demand = lookup(var.instance_groups[floor(count.index / 3)], "autospotting_on_demand", 0)
      autospotting_max_price = lookup(var.instance_groups[floor(count.index / 3)], "autospotting_max_price", 0.03)
      autospotting_instances = distinct(lookup(var.instance_groups[floor(count.index / 3)], "autospotting_instances", [lookup(var.instance_groups[floor(count.index / 3)], "instance_type")]))

      instance_group_name = format(
        "%s-%s",
        lookup(var.instance_groups[floor(count.index / 3)], "name"),
        element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)
      )
    })
  }
}

data "null_data_source" "master_info" {
  count = var.masters_instance_count

  inputs = {
    name      = format("masters-%d-%s", count.index, element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones))
    subnet_id = element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)
  }
}

# @TODO Evaluate spot for masters
data "null_data_source" "master_instance_groups" {
  count = var.masters_instance_count

  inputs = {
    name = "masters"
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_dns            = local.cluster_dns
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      public_ip              = false
      autoscaler             = false
      image                  = ""
      security_group         = aws_security_group.masters.id
      external_lb_name       = join("", aws_elb.public_api.*.name)
      external_target_arn    = ""
      instance_group_name    = element(data.null_data_source.master_info.*.outputs.name, count.index)
      subnet_ids             = [element(data.null_data_source.master_info.*.outputs.subnet_id, count.index)]
      subnet_type            = "private"
      storage_type           = "gp2"
      storage_iops           = 0
      storage_in_gb          = 48
      node_role              = "Master"
      instance_name          = "master"
      instance_max           = 1
      instance_min           = 1
      instance_type          = var.master_machine_type
      autospotting_max_price = 0.19
      autospotting_enabled   = var.masters_spot_enabled && count.index >= var.masters_spot_on_demand
      autospotting_on_demand = count.index < var.masters_spot_on_demand ? 1 : 0
      autospotting_instances = distinct(concat([var.master_machine_type], ["m5.large", "m5.xlarge", "a1.large", "a1.xlarge", "i3.large"]))
    })
  }
}

data "null_data_source" "bastion_instance_group" {
  inputs = {
    name = "bastions"
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_dns            = local.cluster_dns
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      image                  = ""
      external_lb_name       = ""
      autoscaler             = false
      storage_type           = "gp2"
      storage_iops           = 0
      storage_in_gb          = 8
      autospotting_on_demand = 0
      autospotting_enabled   = true
      autospotting_max_price = 0.008
      autospotting_instances = distinct([var.bastion_machine_type, "t2.small", "t2.medium", "t3.small", "t3.medium"])
      subnet_ids             = slice(data.aws_availability_zones.available.names, 0, var.max_availability_zones)
      external_target_arn    = ""
      external_lb_name       = ""
      security_group         = ""
      subnet_type            = "utility"
      instance_group_name    = "bastion"
      node_role              = "Bastion"
      instance_name          = "bastion"
      instance_type          = var.bastion_machine_type
      instance_max           = 1
      instance_min           = var.bastion_default_instance_count

      # Bastion requires VPN connection to be accessed
      public_ip = false
    })
  }
}
