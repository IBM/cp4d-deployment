# AWS Resource Quota Validation

The script `./aws_resource_quota_validation.sh` can be used to determine if the available resources in the AWS account are sufficient to create the desired infrastructure.

The calculation of the resources required by the new infrastructure is based on the terraform configuration specified in the `variables.tf` file.
To get a correct resource quota validation result, it is required to specify the desired infrastructure in the `variables.tf` file before running the script.

## What is the script doing ?
The script:
- creates a virtual python environment in  `$HOME/.aws_python_venv`
- installs required python packages in that virtual python environment: 
   - boto3  -  Boto is the Amazon Web Services (AWS) SDK for Python. See: https://boto3.amazonaws.com/v1/documentation/api/latest/index.html
   - pyhcl  -  Implements a parser for HCL (HashiCorp Configuration Language) in Python. See: https://pypi.org/project/pyhcl/
- executes the python script to do the resource quota validation

The 1st time the script is executed, it installs the required python packages which takes a bit more time.

## Resource quota validation
For the resource quota validation it is necessary to authenticate to the AWS account to retrieve mainly the following information:
- AWS account service quotas
- resources that are already used in the AWS account / AWS region

### AWS user authentication
The tool provides 2 ways to authenticate the user against the AWS account.
1. User provided AWS credentials: 
   The user can enter the AWS credentials via the command line.
1. AWS credentials derived from `$HOME/.aws/credentials`: 
   The tool is able to read the credentials from the default location at `~/.aws/credentials` which the user has created it by e.g. executing `aws configure` in case he/she has installed the AWS CLI. 

### Infrastructure resource calculation
For the calculation of the required resources the following information are derived from the terraform configuration specified in `variables.tf`:
- AWS region
- deployment type: single-zone / multi-zone
- storage type
- number of master nodes
- number of worker nodes
- master node instance type
- worker node instance type
- bootnode type

### Summary output
There is a table printed out showing:
- numbers for availalble resouces
- numbers for required resources needed for the infrastructure creation
- validation check as a `PASSED`/`FAILED` result
