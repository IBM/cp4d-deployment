INSTALLER_PATH=$1
CPD_RELEASE=$2
COMPONENTS=$3
$INSTALLER_PATH/cpd-cli manage apply-olm --release=$CPD_RELEASE --components=$COMPONENTS
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Deploying catalog Sources & subscription failed for $COMPONENTS"
    echo "**********************************"
    exit 1
fi 
