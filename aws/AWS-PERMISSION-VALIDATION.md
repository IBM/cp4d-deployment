# AWS Permission Validation

The script `./aws_permission_validation.sh` checks whether a user has all the required permissions to create an OCP cluster on AWS.

The permissions to be checked need to be listed in a file >actions.txt< which has to be in the same folder. The file content 
looks like:

```
iam:ListUsers
iam:ListAccessKeys
iam:DeleteAccessKey
iam:ListGroupsForUser
iam:RemoveUserFromGroup
iam:DeleteUser
ec2:AllocateAddress
ec2:ModifyVpcAttribute
route53:DeleteHostedZone
...
```

## What is the script doing?
The script:
- creates a virtual python environment in  `$HOME/.aws_python_venv`
- installs required python packages in that virtual python environment: 
   - boto3  -  Boto is the Amazon Web Services (AWS) SDK for Python. See: https://boto3.amazonaws.com/v1/documentation/api/latest/index.html
   - pyhcl  -  Implements a parser for HCL (HashiCorp Configuration Language) in Python. See: https://pypi.org/project/pyhcl/
- executes the python script to do the user permission validation

The 1st time the script is executed, it installs the required python packages which takes a bit more time.

### AWS user authentication
The tool provides 2 ways to authenticate the user against the AWS account.
1. User provided AWS credentials: 
   The user can enter the AWS credentials via the command line.
1. AWS credentials derived from `$HOME/.aws/credentials`: 
   The tool is able to read the credentials from the default location at `~/.aws/credentials` which the user has created it by e.g. executing `aws configure` in case he/she has installed the AWS CLI. 


### Minimal user permissions

The executing user needs the following minimal permissions to do the checks:  
- iam:GetUser  
- iam:SimulatePrincipalPolicy  

which are anyway needed to create an OCP cluster on AWS.  

### Validation output

The script lists the groups the user belongs to, and the policies applied directly 
to the user or achieved by a group policy.

The script list the permissions the user does not have compared to the input 
list. 

### Return code

In case of required permissions not applied to the user the script returns 
with return code 1.

