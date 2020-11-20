locals {
  # zone_count = var.multizone ? 3 : 1
  zones = var.multizone ? ["${var.region}-1", "${var.region}-2", "${var.region}-3"] : ["${var.region}-1"]
}

# Create the VPC
resource "ibm_is_vpc" "this" {
  address_prefix_management = "manual"
  name                      = "${var.unique_id}-vpc"
  resource_group            = var.resource_group_id
}

resource "ibm_is_vpc_address_prefix" "this" {
  count = length(local.zones)
  
  cidr = var.zone_address_prefix_cidr[count.index]
  name = "${var.unique_id}-prefix-${count.index+1}"
  vpc  = ibm_is_vpc.this.id
  zone = local.zones[count.index]
}

# Subnets
resource "ibm_is_subnet" "this" {
  count           = length(local.zones)
  depends_on      = [ibm_is_vpc_address_prefix.this]
  
  ipv4_cidr_block = var.subnet_ip_range_cidr[count.index]
  name            = "${var.unique_id}-subnet-${count.index+1}"
  # TODO network_acl
  public_gateway  = var.enable_public_gateway ? ibm_is_public_gateway.this[count.index].id : null
  resource_group = var.resource_group_id
  vpc             = ibm_is_vpc.this.id
  zone  = local.zones[count.index]
}

# Public Gateways
resource "ibm_is_public_gateway" "this" {
  count = var.enable_public_gateway ? length(local.zones) : 0

  name           = "${var.unique_id}-pgw-${count.index + 1}"
  resource_group = var.resource_group_id
  vpc            = ibm_is_vpc.this.id
  zone           = local.zones[count.index]
}

resource "ibm_is_security_group_rule" "allow_all" {
  direction = "inbound"
  group     = ibm_is_vpc.this.default_security_group
  remote    = "0.0.0.0/0"
}

/*
resource "ibm_is_network_acl" "multizone" {
  name = var.unique_id
  vpc  = ibm_is_vpc.this.id
  dynamic rules {

    for_each = var.acl_rules

    content {
      name        = rules.value.name
      action      = rules.value.action
      source      = rules.value.source
      destination = rules.value.destination
      direction   = rules.value.direction
    }

  }
}
*/
