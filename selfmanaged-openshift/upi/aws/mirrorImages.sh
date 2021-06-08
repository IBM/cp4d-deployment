export LOCAL_REPOSITORY='ocp4/openshift4'
export OCP_RELEASE="4.7.6-x86_64"
export LOCAL_SECRET_JSON="/home/ec2-user/pull-secret"
export PRODUCT_REPO='openshift-release-dev'
export RELEASE_NAME="ocp-release"
export LOCAL_REGISTRY="xxxxxxxxxxxxxx.dkr.ecr.eu-west-1.amazonaws.com"

oc adm -a ${LOCAL_SECRET_JSON} release mirror --max-per-registry=1 \
   --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} \
   --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
   --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}
