# aws-kops-cluster

**Maintained by [@goci-io/prp-<team>](https://github.com/orgs/goci-io/teams/prp-terraform) and [@goci-io/prp-kubernetes](https://github.com/orgs/goci-io/teams/prp-kubernetes)**

This module uses Terraform `templatefile`s and `null_resource` to provision a kubernetes cluster with [kops](https://github.com/kubernetes/kops) on AWS, including the required kops state store (S3 Bucket). Additionally this module allows you to use public and private hosted zone (or both) to connect to the API server. 

You need to have the `kops` binary installed to use this module. The [terraform-k8s-aws](https://github.com/goci-io/docker-terraform-images/tree/master/aws) image provides a fully functional environment to apply and destroy this module. You can also use our copy of [atlantis](https://github.com/goci-io/aws-atlantis-helm) which contains an extended docker image with additional binaries.

### Usage

```hcl
module "kops" {
  source             = ""
  namespace          = "goci"
  stage              = "staging"
  kubernetes_version = "1.16.8"
  api_access_cidrs   = ["1.2.3.4/32]
  ssh_access_cidrs   = ["1.2.3.4/32]
  kops_addons        = [...]
  # ...

  instance_groups = [
    {
      name                   = "worker"
      instance_type          = "t2.medium"
      autospotting_max_price = 0.02
      autospotting_instances = ["t3.medium", "m4.large"]
      # ...
    }
  ]
}
```

**Note:** By default we run **5** masters. If you are intending setting up a small size cluster you might want to set `masters_instance_count` to **3**. When running with 3 masters you can loose one of them without interrupting service. When running 5 masters you can loose 2.

**Note:** By default `max_availability_zones` is set to 3. If you want to span less AZs or even more in specific regions you will want to overwrite this value or simply set it to a high value to cover all AZs available in the current region, specified via `aws_region`.

**Note:** Masters can also be enabled to use spot instances. Default for `masters_spot_enabled` is `false`. The default OnDemand instances is set to **2** using `masters_spot_on_demand`.

**Note:** When creating or updating the cluster its completely normal to run into Rate limit errors. Retries will sort this out. 

<details>
<summary>Example creating cluster pipeline output</summary><p>

#### Pipeline output

```
module.kops.null_resource.kops_update_cluster (local-exec): Cluster is starting.  It should be ready in a few minutes.
module.kops.null_resource.kops_update_cluster (local-exec): Suggestions:
module.kops.null_resource.kops_update_cluster (local-exec):  * validate cluster: kops validate cluster
module.kops.null_resource.kops_update_cluster (local-exec):  * list nodes: kubectl get nodes --show-labels
module.kops.null_resource.kops_update_cluster (local-exec):  * ssh to the bastion: ssh -A -i ~/.ssh/id_rsa admin@bastion.corp.eu1.goci.io
module.kops.null_resource.kops_update_cluster (local-exec):  * the admin user is specific to Debian. If not using Debian please use the appropriate user based on your OS.
module.kops.null_resource.kops_update_cluster (local-exec):  * read about installing addons at: https://github.com/kubernetes/kops/blob/master/docs/operations/addons.md.
module.kops.null_resource.kops_update_cluster: Creation complete after 1m6s [id=5420811948207607124]
module.kops.null_resource.cluster_startup[0]: Creating...
module.kops.null_resource.cluster_startup[0]: Provisioning with 'local-exec'...
module.kops.null_resource.cluster_startup[0] (local-exec): Executing: ["/bin/sh" "-c" ".terraform/modules/kops/scripts/wait-for-cluster.sh"]
module.kops.null_resource.cluster_startup[0] (local-exec): kops has set your kubectl context to corp.eu1.goci.io
module.kops.null_resource.cluster_startup[0] (local-exec): Wait for cluster to start up the first time...
module.kops.null_resource.cluster_startup[0] (local-exec): Waiting 60 seconds before validating cluster
...
```

you may see the following in the first place:

```
module.kops.null_resource.cluster_startup[0] (local-exec): Retrying...
module.kops.null_resource.cluster_startup[0] (local-exec): Validating cluster corp.eu1.goci.io
module.kops.null_resource.cluster_startup[0] (local-exec): unexpected error during validation: error listing nodes: Get https://corp.eu1.goci.io/api/v1/nodes: EOF
module.kops.null_resource.cluster_startup[0] (local-exec): Waiting 90 seconds before validating cluster
```

which is normal behaviour when creating the cluster as none of the masters is currently running and healthy.

Once we can reach the kubernetes API the following validation errors in the first place are fine as it will take some time until all initial machines are ready and have scheduled their kube-system pods for example:

```
module.kops.null_resource.cluster_startup[0] (local-exec): NAME         ROLE    MACHINETYPE MIN MAX SUBNETS
module.kops.null_resource.cluster_startup[0] (local-exec): bastion          Bastion t2.micro    1   1   utility-eu-central-1a,utility-eu-central-1b,utility-eu-central-1c
module.kops.null_resource.cluster_startup[0] (local-exec): masters-0-eu-central-1a  Master  m5.large    1   1   private-eu-central-1a
module.kops.null_resource.cluster_startup[0] (local-exec): masters-1-eu-central-1b  Master  m5.large    1   1   private-eu-central-1b
...
module.kops.null_resource.cluster_startup[0] (local-exec): worker-eu-central-1a Node    t2.medium   1   20  private-eu-central-1a
...
module.kops.null_resource.cluster_startup[0] (local-exec): NAME                     ROLE    READY
module.kops.null_resource.cluster_startup[0] (local-exec): ip-10-100-0-155.eu-central-1.compute.internal    master  True
module.kops.null_resource.cluster_startup[0] (local-exec): ip-10-100-30-175.eu-central-1.compute.internal   node    True
...
module.kops.null_resource.cluster_startup[0] (local-exec): VALIDATION ERRORS
module.kops.null_resource.cluster_startup[0] (local-exec): KIND NAME            MESSAGE
module.kops.null_resource.cluster_startup[0] (local-exec): Machine  i-022326fb6740dc207 machine "i-022326fb6740dc207" has not yet joined cluster
module.kops.null_resource.cluster_startup[0] (local-exec): Pod  kube-system/kube-proxy-ip-10-100-30-175.eu-central-1.compute.internal   kube-system pod "kube-proxy-ip-10-100-30-175.eu-central-1.compute.internal" is pending
...
```

#### Success

```
module.kops.null_resource.cluster_startup[0] (local-exec): Retrying...
module.kops.null_resource.cluster_startup[0] (local-exec): Validating cluster corp.eu1.goci.io
module.kops.null_resource.cluster_startup[0] (local-exec): INSTANCE GROUPS
module.kops.null_resource.cluster_startup[0] (local-exec): NAME         ROLE    MACHINETYPE MIN MAX SUBNETS
module.kops.null_resource.cluster_startup[0] (local-exec): bastion          Bastion t2.micro    1   1   utility-eu-central-1a,utility-eu-central-1b,utility-eu-central-1c
module.kops.null_resource.cluster_startup[0] (local-exec): masters-0-eu-central-1a  Master  m5.large    1   1   private-eu-central-1a
module.kops.null_resource.cluster_startup[0] (local-exec): masters-1-eu-central-1b  Master  m5.large    1   1   private-eu-central-1b
...
module.kops.null_resource.cluster_startup[0] (local-exec): worker-eu-central-1a Node    t2.medium   1   20  private-eu-central-1a
...
module.kops.null_resource.cluster_startup[0] (local-exec): NODE STATUS
module.kops.null_resource.cluster_startup[0] (local-exec): NAME                     ROLE    READY
module.kops.null_resource.cluster_startup[0] (local-exec): ip-10-100-0-155.eu-central-1.compute.internal    master  True
module.kops.null_resource.cluster_startup[0] (local-exec): ip-10-100-30-175.eu-central-1.compute.internal   node    True
module.kops.null_resource.cluster_startup[0] (local-exec): ip-10-100-40-39.eu-central-1.compute.internal    master  True
...
module.kops.null_resource.cluster_startup[0] (local-exec): Your cluster corp.eu1.goci.io is ready
module.kops.null_resource.cluster_startup[0] (local-exec): Cluster startup successful.
module.kops.null_resource.cluster_startup[0]: Creation complete after 7m3s [id=3879641636622307086]
```

Now your cluster is up and running and you can start using it.

#### Failures

The validation errors can already identify a problem or even `kops create cluster` might fail as well with an approriate error. 
In case you don't know whats going on we'd love to hear your feedback and what would have helped you. 
If your cluster does not become healthy you can jump on the nodes and investigate log files (eg `/var/log/kube-apiserver.log` on the masters or `/var/log/kube-proxy.log` on the nodes as well as `/var/log/syslog` (might vary based on your OS)). You can either wait until the pipeline fails and get the SSH private key from the terraform state bucket or maintain your own EC2 SSH access.

</p></details>


<details>
<summary>`kubectl get pods -A` on a fresh cluster</summary><p>

```
bash-5.0# kubectl get pods -A
NAMESPACE         NAME                                                                     READY   STATUS              RESTARTS   AGE
kube-system       calico-kube-controllers-8b55685cc-drwk2                                  1/1     Running             0          6m36s
kube-system       calico-node-4gf42                                                        1/1     Running             0          5m23s
kube-system       calico-node-7qg7x                                                        1/1     Running             0          6m6s
kube-system       calico-node-d2chd                                                        1/1     Running             0          4m37s
kube-system       calico-node-hfmqs                                                        1/1     Running             0          5m23s
kube-system       calico-node-jnckz                                                        1/1     Running             0          6m33s
kube-system       calico-node-jrvsd                                                        1/1     Running             0          6m30s
kube-system       calico-node-z6h4c                                                        1/1     Running             0          5m33s
kube-system       calico-node-z7q9l                                                        1/1     Running             0          6m34s
kube-system       dns-controller-ccd4cc8c9-zkxv5                                           1/1     Running             0          6m33s
kube-system       etcd-manager-events-ip-10-100-0-155.eu-central-1.compute.internal        1/1     Running             0          5m40s
kube-system       etcd-manager-events-ip-10-100-40-39.eu-central-1.compute.internal        1/1     Running             0          5m8s
kube-system       etcd-manager-events-ip-10-100-59-215.eu-central-1.compute.internal       1/1     Running             0          5m58s
kube-system       etcd-manager-events-ip-10-100-6-190.eu-central-1.compute.internal        1/1     Running             0          6m4s
kube-system       etcd-manager-events-ip-10-100-83-59.eu-central-1.compute.internal        1/1     Running             0          5m47s
kube-system       etcd-manager-main-ip-10-100-0-155.eu-central-1.compute.internal          1/1     Running             0          5m32s
kube-system       etcd-manager-main-ip-10-100-40-39.eu-central-1.compute.internal          1/1     Running             0          5m12s
kube-system       etcd-manager-main-ip-10-100-59-215.eu-central-1.compute.internal         1/1     Running             0          5m27s
kube-system       etcd-manager-main-ip-10-100-6-190.eu-central-1.compute.internal          1/1     Running             0          5m58s
kube-system       etcd-manager-main-ip-10-100-83-59.eu-central-1.compute.internal          1/1     Running             0          5m41s
kube-system       kops-controller-9r56s                                                    1/1     Running             0          5m13s
kube-system       kops-controller-js8x5                                                    1/1     Running             0          6m18s
kube-system       kops-controller-lgfpm                                                    1/1     Running             0          6m24s
kube-system       kops-controller-lrmw7                                                    1/1     Running             0          5m56s
kube-system       kops-controller-vmrt8                                                    1/1     Running             0          6m13s
kube-system       kube-apiserver-ip-10-100-0-155.eu-central-1.compute.internal             1/1     Running             2          6m1s
kube-system       kube-apiserver-ip-10-100-40-39.eu-central-1.compute.internal             1/1     Running             3          4m25s
kube-system       kube-apiserver-ip-10-100-59-215.eu-central-1.compute.internal            1/1     Running             2          5m38s
kube-system       kube-apiserver-ip-10-100-6-190.eu-central-1.compute.internal             1/1     Running             2          5m52s
kube-system       kube-apiserver-ip-10-100-83-59.eu-central-1.compute.internal             1/1     Running             3          4m56s
kube-system       kube-controller-manager-ip-10-100-0-155.eu-central-1.compute.internal    1/1     Running             0          5m49s
kube-system       kube-controller-manager-ip-10-100-40-39.eu-central-1.compute.internal    1/1     Running             0          4m30s
kube-system       kube-controller-manager-ip-10-100-59-215.eu-central-1.compute.internal   1/1     Running             0          5m37s
kube-system       kube-controller-manager-ip-10-100-6-190.eu-central-1.compute.internal    1/1     Running             0          5m51s
kube-system       kube-controller-manager-ip-10-100-83-59.eu-central-1.compute.internal    1/1     Running             0          5m39s
kube-system       kube-dns-autoscaler-594dcb44b5-gxvq5                                     1/1     Running             0          6m36s
kube-system       kube-dns-b84c667f4-74w9k                                                 3/3     Running             0          4m58s
kube-system       kube-dns-b84c667f4-sx4lw                                                 3/3     Running             0          6m37s
kube-system       kube-proxy-ip-10-100-0-155.eu-central-1.compute.internal                 1/1     Running             0          6m9s
kube-system       kube-proxy-ip-10-100-30-175.eu-central-1.compute.internal                1/1     Running             0          4m49s
kube-system       kube-proxy-ip-10-100-40-39.eu-central-1.compute.internal                 1/1     Running             0          4m35s
kube-system       kube-proxy-ip-10-100-55-203.eu-central-1.compute.internal                1/1     Running             0          4m33s
kube-system       kube-proxy-ip-10-100-59-215.eu-central-1.compute.internal                1/1     Running             0          5m21s
kube-system       kube-proxy-ip-10-100-6-190.eu-central-1.compute.internal                 1/1     Running             0          6m14s
kube-system       kube-proxy-ip-10-100-83-59.eu-central-1.compute.internal                 1/1     Running             0          5m56s
kube-system       kube-proxy-ip-10-100-92-54.eu-central-1.compute.internal                 1/1     Running             0          4m32s
kube-system       kube-scheduler-ip-10-100-0-155.eu-central-1.compute.internal             1/1     Running             0          6m10s
kube-system       kube-scheduler-ip-10-100-40-39.eu-central-1.compute.internal             1/1     Running             0          5m2s
kube-system       kube-scheduler-ip-10-100-59-215.eu-central-1.compute.internal            1/1     Running             0          6m31s
kube-system       kube-scheduler-ip-10-100-6-190.eu-central-1.compute.internal             1/1     Running             0          6m3s
kube-system       kube-scheduler-ip-10-100-83-59.eu-central-1.compute.internal             1/1     Running             0          5m39s
```

</p></details>

There are different kinds of setup. Please refer to the detailed setup documentation for recommendations and example setups.

#### Private Cluster

The private cluster is the most secure way to setup a kubernetes cluster. Private cluster means that no one from an unknown source (eg: based on IP or only accepted when connected through a VPN) can access your kubernetes API server. By restricting who can access your kubernetes API server you are less likely a target for vulnerabilities effecting the API server, assuming your are only running trusted applications in your cluster. The following demonstrates a private setup:

```hcl

module "kops" {
  source             = ""
  namespace          = "goci"
  stage              = "staging"
  cluster_dns_type   = "Private"
  tf_bucket          = "my-terraform-state-bucket"
  vpc_module_state   = "vpc/terraform.tfstate"

  instance_groups = [
    {
      name                   = "worker"
      instance_type          = "t2.medium"
    }
  ]
}
```

You can still create public Ingress resources to route traffic using a different load balancer (eg by using a `Service` with type `LoadBalancer`) to your applications.

**Note:** You can also pass vpc and subnet details into the module without using remote state references. The above example assumes you habe a vpc with remote state already installed. Kops can also generate a VPC for you. This scenario is currently not covered. Let us know if you run into any issues!

#### Kops validation

By default when spinning up the cluster the first time the script [`scripts/wait-for-cluster.sh`] is executed and runs `kops validate cluster`, awaiting a healthy cluster state. Keep in mind once you spin up a cluster we will need for: EC2 instances, Route53 records and the API server and required tools becoming ready and healthy. This may take a while. If you anyway need to disable the initial validation you can set `enable_kops_validation` to `false`. When updating the cluster we assume other machanisms in place when the cluster is put in a bad state after a rollout. Most changes are only rolled out once a new EC2 node comes up. You can also force the update by using `kops rolling-update cluster`. We might offer in the feature to combine the `kops update` with a rolling update if required, but usually this is something requiring some kind of approval/review process before updating.

#### Instance group configuration

The `instance_groups` attribute can be configured with any type of instance group. The following shows a complete example of an instance group configuration:

```hcl
instance_groups = [
  {
    name                    = "ig-name"
    image                   = "EC2 AMI, overwrites kops default"
    count_min               = 1
    count_max               = 5
    subnet                  = "private|utility" # Subnet defaults to private and should generally not be changed
    storage_type            = "gp2"
    storage_iops            = 0
    storage_in_gb           = 32
    security_group          = ""
    loadbalancer_name       = ""
    loadbalancer_target_arn = ""
    autospotting_enabled    = true
    autospotting_max_price  = 0.03
    autospotting_instances  = []
    autospotting_on_demand  = 0
  }
]
```

**Note:** If you set all instance groups to `min_count=0` but need at least one worker node running to schedule some tools on non-master nodes you can set `require_one_worker_node` to `true`. In that case the first IG has a `Desired` state of 1 in one AZ to spawn exactly one worker node.

**Note:** You dont need to specify master or bastion instance group details. There are other variables available to configure these instance groups.

#### Deploying into external Account

If you have for example the CI system running in a dedicated AWS Account but want to create the Kubernetes Cluster in a different one you can configure the following settings to deploy the cluster into an external Account:

```hcl
external_account    = true # Creates an IAM user in external Account
aws_account_id      = "123456789012"
aws_assume_role_arn = "arn:aws:iam::account-id:role/role-name-with-path"
```

If you want to rotate the credentials simply delete the credential Pair from AWS IAM user created by this module to generate a new pair.

#### Permissions

To attach additional permissions to your master nodes you can specify either inline policies by using `additional_master_policies` or attach existing policies using `external_master_policies`.
