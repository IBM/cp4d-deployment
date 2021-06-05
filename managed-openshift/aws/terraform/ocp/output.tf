output "login_cmd" {
  value = regex("oc\\s.*", data.local_file.creds.content)
}