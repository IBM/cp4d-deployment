data "template_file" "icsp_dev" {
  template = <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: mirror-config
spec:
  repositoryDigestMirrors:
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    - cp.stg.icr.io/cp
    - hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom
    source: quay.io/opencloudio
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    - cp.stg.icr.io/cp
    source: icr.io/cpopen
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    - cp.stg.icr.io/cp
    source: docker.io/ibmcom
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    - cp.stg.icr.io/cp
    source: cp.icr.io/cp/cpd
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    - cp.stg.icr.io/cp
    source: cp.icr.io/cp
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    source: icr.io/cpopen/cpfs
  - mirrors:
    - cp.stg.icr.io/db2u
    source: icr.io/db2u
EOF
}

data "template_file" "play_env" {
template = <<EOF
export CASECTL_RESOLVERS_LOCATION=/tmp/work/resolvers.yaml
export CASECTL_RESOLVERS_AUTH_LOCATION=/tmp/work/resolvers_auth.yaml
export CASE_TOLERATION='-t 1'
export GITHUB_TOKEN='${var.github_ibm_pat}'
export CLOUDCTL_TRACE=true
export CASE_REPO_PATH="https://${var.github_ibm_pat}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.5.0-Snapshot-20220606.093728.134-365/promoted/case-repo-promoted"
export OPENCONTENT_CASE_REPO_PATH="https://${var.github_ibm_pat}@raw.github.ibm.com/IBMPrivateCloud/cloud-pak/master/repo/case"
export CPFS_CASE_REPO_PATH="https://${var.github_ibm_pat}@raw.github.ibm.com/IBMPrivateCloud/cloud-pak/master/repo/case"
EOF
}

data "template_file" "resolvers_auth" {
template = <<EOF
resolversAuth:
  metadata:
    description:  This is the INTERNAL authorization file for downloading CASE packages from an internal repo
  resources:
    cases:
      repositories:
        DevGitHub:
          credentials:
            basic:
              username: '${var.github_ibm_username}'
              password: '${var.github_ibm_pat}'
        cloudPakCertRepo:
          credentials:
            basic:
              username: '${var.github_ibm_username}'
              password: '${var.github_ibm_pat}'
    containerImages:
      registries:
        entitledStage:
          credentials:
            basic:
              username: iamapikey
              password: $secret_api_key
EOF
}

data "template_file" "resolvers" {
template = <<EOF
resolvers:
  metadata:
    description:  resolver file to map cases and registries. Used to get dependency cases
  resources:
    cases:
      repositories:
        PromotedGitHub:
          repositoryInfo:
            url: "https://raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.5.0-Snapshot-20220606.093728.134-365/promoted/case-repo-promoted"
    	  cloudPakCertRepo:
          repositoryInfo:
            url: "https://raw.github.ibm.com/IBMPrivateCloud/cloud-pak/master/repo/case"
      caseRepositoryMap:
      - cases:
        - case: "ibm-ccs"
          version: "*"
        - case: "ibm-datarefinery"
          version: "*"
        - case: "ibm-wsl-runtimes"
          version: "*"
        - case: "ibm-db2uoperator"
          version: "*"
        - case: "ibm-iis"
          version: "*"
        - case: "ibm-db2aaservice"
          version: "*"
        - case: "ibm-wsl"
          version: "*"
        - case: "*"
          version: "*"
        repositories:
        - PromotedGitHub
      - cases:
        - case: "*"
          version: "*"
        repositories:
        - cloudPakCertRepo
EOF
}

resource "local_file" "icsp_dev_yaml" {
  content  = data.template_file.icsp_dev.rendered
  filename = "${local.cpd_workspace}/dev_icsp.yaml"
}

resource "local_file" "play_env_sh" {
  content  = data.template_file.play_env.rendered
  filename = "${local.cpd_workspace}/play_env.sh"
}

resource "local_file" "resolvers_auth_yaml" {
  content  = data.template_file.resolvers_auth.rendered
  filename = "${local.cpd_workspace}/resolvers_auth.yaml"
}

resource "local_file" "resolvers_yaml" {
  content  = data.template_file.resolvers.rendered
  filename = "${local.cpd_workspace}/resolvers.yaml"
}

resource "null_resource" "configure_dev_cluster" {
  triggers = {
    installer_workspace = var.installer_workspace
    cpd_workspace       = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF

echo "Configure Dev repos creds in global pull secret"
export OLM_UTILS_IMAGE=cp.stg.icr.io/cp/cpd/olm-utils:20220606.093728.134


${self.triggers.cpd_workspace}/cpd-cli manage add-cred-to-global-pull-secret  '${var.cpd_staging_registry}'  '${var.cpd_staging_username}'  '${var.cpd_staging_api_key}'


${self.triggers.cpd_workspace}/cpd-cli manage add-cred-to-global-pull-secret '${var.hyc_cloud_private_registry}'  '${var.hyc_cloud_private_username}'  '${var.hyc_cloud_private_api_key}'



oc apply -f ${self.triggers.cpd_workspace}/dev_icsp.yaml
echo 'Sleeping for 1mins while icsp apply' 
sleep 60

echo 'settng up play_env.sh,resolvers file'
cp ${self.triggers.cpd_workspace}/play_env.sh cpd-cli-workspace/olm-utils-workspace/work/play_env.sh
cp ${self.triggers.cpd_workspace}/resolvers.yaml cpd-cli-workspace/olm-utils-workspace/work/resolvers.yaml
cp ${self.triggers.cpd_workspace}/resolvers_auth.yaml cpd-cli-workspace/olm-utils-workspace/work/resolvers_auth.yaml
EOF
  }
  depends_on = [
    local_file.icsp_dev_yaml,
    null_resource.login_cluster,
    null_resource.node_check,
    module.machineconfig,
  ]
}

