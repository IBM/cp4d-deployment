locals {
  create_resources = var.existing_vpc_id == null
  zones = var.multizone ? ["${var.region}-1", "${var.region}-2", "${var.region}-3"] : ["${var.region}-1"]
}

terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
}

resource "ibm_is_vpc" "this" {
  count = local.create_resources ? 1 : 0
  address_prefix_management = "manual"
  name                      = "${var.unique_id}-vpc"
  resource_group            = var.resource_group_id
}

resource "ibm_is_vpc_address_prefix" "this" {
  count = local.create_resources ? var.no_of_zones : 0
  
  cidr = var.zone_address_prefix_cidr[count.index]
  name = "${var.unique_id}-prefix-${count.index+1}"
  vpc  = ibm_is_vpc.this[0].id
  zone = local.zones[count.index]
}

resource "ibm_is_subnet" "this" {
  count           = local.create_resources ? var.no_of_zones : 0
  depends_on      = [ibm_is_vpc_address_prefix.this]
  
  ipv4_cidr_block = var.subnet_ip_range_cidr[count.index]
  name            = "${var.unique_id}-subnet-${count.index+1}"
  network_acl     = ibm_is_network_acl.this[0].id
  public_gateway  = var.enable_public_gateway ? ibm_is_public_gateway.this[count.index].id : null
  resource_group  = var.resource_group_id
  vpc             = ibm_is_vpc.this[0].id
  zone            = local.zones[count.index]
}

resource "ibm_is_public_gateway" "this" {
  count = local.create_resources && var.enable_public_gateway ? var.no_of_zones : 0

  name           = "${var.unique_id}-pgw-${count.index + 1}"
  resource_group = var.resource_group_id
  vpc            = ibm_is_vpc.this[0].id
  zone           = local.zones[count.index]
}

# resource "ibm_is_security_group_rule" "allow_all" {
#   count = local.create_resources ? 1 : 0
#
#   direction = "inbound"
#   group     = ibm_is_vpc.this[0].default_security_group
#   remote    = "0.0.0.0/0"
# }

resource "ibm_is_network_acl" "this" {
  count = local.create_resources ? 1 : 0

  name           = var.unique_id
  vpc            = ibm_is_vpc.this[0].id
  resource_group = var.resource_group_id
  
  dynamic "rules" {
    for_each = var.acl_rules
    content {
      name        = rules.value.name
      action      = rules.value.action
      source      = rules.value.source
      destination = rules.value.destination
      direction   = rules.value.direction
      
      dynamic "icmp" {
        for_each = lookup(rules.value, "icmp", [])
        content {
          code = icmp.code
          type = icmp.type
        }
      }
      dynamic "tcp" {
        for_each = lookup(rules.value, "tcp", [])
        content {
          port_max = tcp.value.port_max
          port_min = tcp.value.port_min
          source_port_max = tcp.value.source_port_max
          source_port_min = tcp.value.source_port_min
        }
      }
      dynamic "udp" {
        for_each = lookup(rules.value, "udp", [])
        content {
          port_max = udp.value.port_max
          port_min = udp.value.port_min
          source_port_max = udp.value.source_port_max
          source_port_min = udp.value.source_port_min
        }
      }
    }
  }
}
