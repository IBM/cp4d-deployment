output "vpc_id" {
  description = "ID of the VPC"
  value = local.create_resources ? ibm_is_vpc.this[0].id : var.existing_vpc_id
}

# output "zone_subnet_id_map" {
#   description = "Map where key is the zone name and value is the id of the subnet created in that zone"
#   value = zipmap(local.zones, ibm_is_subnet.this.*.id)
# }

output "vpc_subnets" {
  description = "List of IDs of the subnets"
  value = local.create_resources ? ibm_is_subnet.this.*.id : var.existing_vpc_subnets
}
