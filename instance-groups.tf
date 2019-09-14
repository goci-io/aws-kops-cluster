data "null_data_source" "instance_groups" {
  count = length(var.instance_groups) * var.max_availability_zones

  inputs = {
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
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
      instance_max           = lookup(var.instance_groups[floor(count.index / 3)], "count_max", 3)
      instance_min           = lookup(var.instance_groups[floor(count.index / 3)], "count_min", 1)
      storage_type           = lookup(var.instance_groups[floor(count.index / 3)], "storage_type", "gp2")
      storage_iops           = lookup(var.instance_groups[floor(count.index / 3)], "storage_iops", 168)
      storage_in_gb          = lookup(var.instance_groups[floor(count.index / 3)], "storage_in_gb", 56)
      autospotting_enabled   = lookup(var.instance_groups[floor(count.index / 3)], "autospotting", false)
      autospotting_max_price = lookup(var.instance_groups[floor(count.index / 3)], "autospotting", false) ? format("maxPrice: \"%d\"", lookup(var.instance_groups[floor(count.index / 3)], "autospotting_max_price", "0.03")) : ""

      instance_group_name = format(
        "%s-%s", 
        lookup(var.instance_groups[floor(count.index / 3)], "name"), 
        element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)
      )

      aws_subnet_id = format(
        "%s-%s", 
        lookup(var.instance_groups[floor(count.index / 3)], "subnet", "private"), 
        element(data.aws_availability_zones.available.names, count.index % var.max_availability_zones)
      )
    })
  }
}

data "null_data_source" "master_instance_groups" {
  count = var.max_availability_zones

  inputs = {
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_name           = local.cluster_name
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      public_ip              = false
      image                  = local.kops_default_image
      instance_group_name    = format("master-%s", data.aws_availability_zones.available.names[count.index])
      aws_subnet_id          = format("private-%s", data.aws_availability_zones.available.names[count.index])
      autoscaler             = "off"
      storage_type           = "io1"
      storage_iops           = 480
      storage_in_gb          = 156
      autospotting_enabled   = false
      autospotting_max_price = ""
      node_role              = "Master"
      instance_name          = "master"
      instance_type          = var.master_machine_type
      instance_max           = 1
      instance_min           = 1
    })
  }
}

data "null_data_source" "bastion_instance_group" {
  inputs = {
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_name           = local.cluster_name
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      public_ip              = true
      image                  = local.kops_default_image
      aws_subnet_id          = join("\n  - utility-", data.aws_availability_zones.available.names)
      autoscaler             = "off"
      storage_type           = "gp2"
      storage_iops           = 0
      storage_in_gb          = 6
      autospotting_enabled   = true
      autospotting_max_price = "maxPrice: \"0.005\""
      instance_group_name    = "bastion"
      node_role              = "Bastion"
      instance_name          = "bastion"
      instance_type          = var.bastion_machine_type
      instance_max           = 1
      instance_min           = 1
    })
  }
}
