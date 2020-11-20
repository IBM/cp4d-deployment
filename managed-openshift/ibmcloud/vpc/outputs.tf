output "vpc_id" {
  value = ibm_is_vpc.this.id
}

output "vpc_name" {
  value = ibm_is_vpc.this.name
}

output "zone_subnet_id_map" {
  description = "Map where key is the zone name and value is the id of the subnet created in that zone"
  value = zipmap(local.zones, ibm_is_subnet.this.*.id)
}
