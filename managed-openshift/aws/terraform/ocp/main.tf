locals {
  installer_workspace = "${path.root}/installer-files"
  rosa_installer_url  = "https://github.com/openshift/rosa/releases/download/v1.0.8/rosa-linux-amd64"
}

resource "null_resource" "download_binaries" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
test -e ${self.triggers.installer_workspace} || mkdir ${self.triggers.installer_workspace}
case $(uname -s) in
  Darwin)
    wget -r -l1 -np -nd -q https://github.com/openshift/rosa/releases/download/v1.0.8/rosa-darwin-amd64 -P ${self.triggers.installer_workspace} -A 'rosa-darwin-amd64'
    chmod u+x ${self.triggers.installer_workspace}/rosa-darwin-amd64
    mv ${self.triggers.installer_workspace}/rosa-darwin-amd64 ${self.triggers.installer_workspace}/rosa
    ;;
  Linux)
    wget -r -l1 -np -nd -q https://github.com/openshift/rosa/releases/download/v1.0.8/rosa-linux-amd64 -P ${self.triggers.installer_workspace} -A 'rosa-linux-amd64'
    chmod u+x ${self.triggers.installer_workspace}/rosa-linux-amd64
    mv ${self.triggers.installer_workspace}/rosa-darwin-amd64 ${self.triggers.installer_workspace}/rosa
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
#rm -rf ${self.triggers.installer_workspace}
EOF
  }
}

resource "null_resource" "install_rosa" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
${self.triggers.installer_workspace}/rosa create cluster --cluster-name ${var.cluster_name} --compute-machine-type ${var.worker_machine_type} --compute-nodes ${var.worker_machine_count} --region ${var.region} --watch
EOF

  }
}
