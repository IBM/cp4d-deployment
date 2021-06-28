output "vpcid" {
  value = aws_vpc.cpdvpc.id
}

output "public_subnet1_id" {
  value = aws_subnet.public1.id
}

output "public_subnet2_id" {
  value = aws_subnet.public2[*].id
}

output "public_subnet3_id" {
  value = aws_subnet.public3[*].id
}

output "private_subnet1_id" {
  value = aws_subnet.private1.id
}

output "private_subnet2_id" {
  value = aws_subnet.private2[*].id
}

output "private_subnet3_id" {
  value = aws_subnet.private3[*].id
}