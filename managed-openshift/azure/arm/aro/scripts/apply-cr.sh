INSTALLER_PATH=$1
CPD_RELEASE=$2
COMPONENTS=$3
NAMESPACE=$4
SC_VENDOR=$5
FILE_SC=$6
BLOCK_SC=$7
if [[ "$SC_VENDOR" != "portworx" ]]
then
   $INSTALLER_PATH/cpd-cli manage apply-cr --release=$CPD_RELEASE --components=$COMPONENTS  --license_acceptance=true --cpd_instance_ns=$NAMESPACE --file_storage_class=$FILE_SC --block_storage_class=$BLOCK_SC
else
  $INSTALLER_PATH/cpd-cli manage apply-cr --release=$CPD_RELEASE --components=$COMPONENTS  --license_acceptance=true --cpd_instance_ns=$NAMESPACE --storage_vendor=portworx
fi
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Applying CR for $COMPONENTS failed"
    echo "**********************************"
    exit 1
fi 