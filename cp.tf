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



