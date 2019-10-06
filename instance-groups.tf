
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

    rendered = templatefile("${path.module}/templates/instance-group${lookup(var.instance_groups[floor(count.index / 3)], "autospotting", true) ? "-spot" : ""}.yaml", {
      cluster_name           = local.cluster_name
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      autoscaler             = "enabled"
      node_role              = "Node"
      public_ip              = false
      image                  = lookup(var.instance_groups[floor(count.index / 3)], "image", local.kops_default_image)
      instance_name          = lookup(var.instance_groups[floor(count.index / 3)], "name")
      instance_type          = lookup(var.instance_groups[floor(count.index / 3)], "instance_type")
      instance_max           = lookup(var.instance_groups[floor(count.index / 3)], "count_max", 5)
      instance_min           = lookup(var.instance_groups[floor(count.index / 3)], "count_min", 1)
      external_lb_name       = lookup(var.instance_groups[floor(count.index / 3)], "loadbalancer_name", "")
      external_target_arn    = lookup(var.instance_groups[floor(count.index / 3)], "loadbalancer_target_arn", "")
      storage_type           = lookup(var.instance_groups[floor(count.index / 3)], "storage_type", "gp2")
      storage_iops           = lookup(var.instance_groups[floor(count.index / 3)], "storage_iops", 0)
      storage_in_gb          = lookup(var.instance_groups[floor(count.index / 3)], "storage_in_gb", 56)
      subnet_type            = lookup(var.instance_groups[floor(count.index / 3)], "subnet", "private")
      subnet_ids             = [element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)]
      autospotting_max_price = lookup(var.instance_groups[floor(count.index / 3)], "autospotting_max_price", 0.03)
      autospotting_instances = lookup(var.instance_groups[floor(count.index / 3)], "autospotting_instances", [lookup(var.instance_groups[floor(count.index / 3)], "instance_type")])

      instance_group_name = format(
        "%s-%s",
        lookup(var.instance_groups[floor(count.index / 3)], "name"),
        element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)
      )
    })
  }
}

# @TODO Evaluate spot for masters
data "null_data_source" "master_instance_group" {
  inputs = {
    name = "masters"
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_name        = local.cluster_name
      namespace           = var.namespace
      stage               = var.stage
      region              = var.region
      public_ip           = false
      image               = local.kops_default_image
      external_lb_name    = local.external_lb_name_masters
      external_target_arn = local.external_lb_target_arn
      subnet_ids          = data.aws_availability_zones.available.names
      subnet_type         = "private"
      instance_group_name = "masters"
      autoscaler          = "off"
      storage_type        = "io1"
      storage_iops        = 468
      storage_in_gb       = 156
      node_role           = "Master"
      instance_name       = "master"
      instance_type       = var.master_machine_type
      instance_max        = var.master_instance_count
      instance_min        = var.master_instance_count
    })
  }
}

data "null_data_source" "bastion_instance_group" {
  inputs = {
    name = "bastions"
    rendered = templatefile("${path.module}/templates/instance-group-spot.yaml", {
      cluster_name           = local.cluster_name
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      image                  = local.kops_default_image
      external_lb_name       = ""
      autoscaler             = "off"
      storage_type           = "gp2"
      storage_iops           = 0
      storage_in_gb          = 8
      autospotting_max_price = 0.008
      autospotting_instances = distinct([var.bastion_machine_type, "t2.small", "t2.medium", "t3.small", "t3.medium"])
      subnet_ids             = data.aws_availability_zones.available.names
      subnet_type            = "utility"
      instance_group_name    = "bastion"
      node_role              = "Bastion"
      instance_name          = "bastion"
      instance_type          = var.bastion_machine_type
      instance_max           = 1
      instance_min           = 1

      # Bastion requires VPN connection to be accessed
      public_ip = false
    })
  }
}
