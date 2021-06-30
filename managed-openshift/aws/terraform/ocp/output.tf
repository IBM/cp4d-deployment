output "login_cmd" {
  value = regex("oc\\s.*", data.local_file.creds.content)
}

/* output "cluster_api" {
  value = regex("https://api.*", data.local_file.creds.content)
} */