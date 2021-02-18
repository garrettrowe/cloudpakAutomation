data "local_file" "configs" {
  filename = join("", ["../", sort(fileset("../", "job-log*"))[0]])
}

locals {
    instnum = regex("([^\\.][a-zA-Z0-9_]*-SchematicBP\\w+)", data.local_file.configs.content)[0]
    company = regex("[a-zA-Z0-9_ ]+", local.instnum)
    demoandindustry = replace(regex("-SchematicBP_\\w*", local.instnum), "-SchematicBP_", "")
    demo = split("_", local.demoandindustry)[1]
    industry = split("_", local.demoandindustry)[0]
    companysafe = lower(replace(local.company, "_", "-"))
}

data "logship" "startlog" {
  log = "Starting Terraform"
  instance = local.instnum
}

resource "ibm_iam_access_group" "accgrp" {
  name        = "${local.companysafe}-group"
  description = "${local.company} access group"
}
resource "ibm_resource_group" "group" {
  name = local.company
}
resource "ibm_iam_access_group_policy" "policy" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles        = ["Operator", "Writer", "Reader", "Viewer", "Editor"]

  resources {
    resource_group_id = ibm_resource_group.group.id
  }
}
resource "ibm_iam_user_invite" "invite_user" {
    users = ["automation@daidemos.com"]
    access_groups = [ibm_iam_access_group.accgrp.id]
}

resource "ibm_is_vpc" "testacc_vpc" {
  name = "${local.companysafe}-cp4d"
  resource_group = ibm_resource_group.group.id
}
data "logship" "vpclog" {
  log = "Created VPC: ${ibm_is_vpc.testacc_vpc.name}"
  instance = local.instnum
}

resource "ibm_is_subnet" "testacc_subnet" {
  name            = "${local.companysafe}-cp4d"
  vpc             = ibm_is_vpc.testacc_vpc.id
  resource_group  = ibm_resource_group.group.id
  zone            = "us-south-1"
  ipv4_cidr_block = "10.240.0.0/24"
  public_gateway  = ibm_is_public_gateway.publicgateway1.id
}
data "logship" "subnetlog" {
  log = "Created Subnet: ${ibm_is_subnet.testacc_subnet.name}"
  instance = local.instnum
}
  
resource "ibm_is_public_gateway" "publicgateway1" {
  name = "${local.companysafe}-cp4d"
  vpc  = ibm_is_vpc.testacc_vpc.id
  zone = "us-south-1"
  resource_group = ibm_resource_group.group.id
}
data "logship" "gatewaylog" {
  log = "Created Gateway: ${ibm_is_public_gateway.publicgateway1.name}"
  instance = local.instnum
}

resource "ibm_is_security_group" "testacc_security_group" {
    name = "${local.companysafe}-securitygroup"
    resource_group = ibm_resource_group.group.id
    vpc = ibm_is_vpc.testacc_vpc.id
}



resource "ibm_is_security_group_rule" "testacc_security_group_rule_all_ib" {
    group = ibm_is_security_group.testacc_security_group.id
    direction = "inbound"
    remote = "0.0.0.0/0"
 }

resource "ibm_is_security_group_rule" "testacc_security_group_rule_all_ob" {
    group = ibm_is_security_group.testacc_security_group.id
    direction = "outbound"
    remote = "0.0.0.0/0"
 }


resource "sshkey" "testacc_sshkey" {
  name       = "automationmanager"
  resource_group = ibm_resource_group.group.id
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBtG5XWo4SkYH6AxNI536z2O3IPznhURL1EYiYwKLbJhjJdEYme7TWucgStHrCcNriiT021Rjq85iL/Imqu9/knNSWMBwZtPLEi5PmnOFHeNlYcVEGhhiuAHN47LPn9+ycQhIc6ECJEGvmbQZeDxLkYu/Ky2xsIFH+71iuanonmlEWDyesEv3b5ev8ELu/pp3z997eqtiD5TqIxA5SxLinZ8dA71UAjE8uemPunqPDhY2K9tHzRawkswckPywNs/ARUmdoAko+DKrJ9VooYPz/NY0Tguy7u3Lend+d8/Mt3snyLc4b5VEPe3O0G2/CVIzNfXAbhrhlTgr8UfoxrDpYtCfn/Hf2GQPpORgqj99SHKXU+1lb4D5vyc7TTMAhksToDpcw4w22jJGLrYZ8yvrKGvCWlgZASyvMrpwInwMN9Lt+rJkzyX2jyc9ATQuGDJpshObEDBRkknpaCMdw0iwcmZYAlcHxV1j9doiBKugMjN6q1Xv5cWEi5h8gOGOzVKO+flltjkcKEceMFJhpD3E8LWm8f0d3khSbpyjjfhiCj7S7iyWBcSmzVbPOC7ObcHZq4RcpwdP3mfzjh1RGl0sGUhcvZL2uMmIutNZkPGcWLpDSY67M6reE7Wst6AMeOPERay2FXeHc+kPoMcNLiiizwwNdxL9q54B8sItYCxvv9Q== automationmanager"
}

resource "ibm_resource_instance" "cos_cp4d" {
  name     = "${local.companysafe}-cos"
  service  = "cloud-object-storage"
  plan     = "standard"
  location = "global"
}

resource "ibm_container_vpc_cluster" "cluster" {
  name              = "${local.companysafe}-cp4d"
  vpc_id            = ibm_is_vpc.testacc_vpc.id
  kube_version      = "4.6_openshift"
  flavor            = "bx2.16x64"
  worker_count      = "4"
  entitlement       = "cloud_pak"
  disable_public_service_endpoint = false
  cos_instance_crn  = ibm_resource_instance.cos_cp4d.id
  resource_group_id = ibm_resource_group.group.id
  zones {
      subnet_id = ibm_is_subnet.testacc_subnet.id
      name      = "us-south-1"
    }
}






