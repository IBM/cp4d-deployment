'''
Resource quota validation for AWS accounts
'''

from libs_aws.aws_configuration_helper import AWSConfigurationHelper
from libs_aws.aws_generic_helper import AWSGenericHelper
from libs_aws.ec2_helper import EC2Helper
from libs_aws.elb_helper import ELBHelper
from libs_aws.elb_v2_helper import ELBv2Helper
from libs_aws.s3_helper import S3Helper
from libs_aws.service_quotas_helper import ServiceQuotasHelper

import os

from pprint import pprint

import sys


# OCP version to be used (if needed - can be requested via user input)
ocp_version = '4.5'

# OpenShift required resources
# instances are handeled separately
ocp = {
    '4.5': {
            'single_zone': {
                                'vpcs': 1,
                                'network-interfaces': 14,
                                'nat-gateways': 3,
                                'security-groups': 6,
                                'elastic-ips': 1,
                                'application-load-ballancer': 2,
                                'classic-load-ballancer': 1,
                                's3-buckets': 2
                            },
            'multi_zone':  {
                                'vpcs': 1,
                                'network-interfaces': 14,
                                'nat-gateways': 3,
                                'security-groups': 6,
                                'elastic-ips': 3,
                                'application-load-ballancer': 2,
                                'classic-load-ballancer': 1,
                                's3-buckets': 2
                            }
            }
}


def get_terraform_configuration():

    print("\nCluster configuration")
    print("=====================")

    tf_var_file = os.path.dirname(os.path.abspath(__file__)) + '/variables.tf'
    print("  The cluster configuration will be derived from terraform " +
          f"configuration: '{tf_var_file}'\n")

    tf_config = {}
    tf_config['replica_count'] = {}
    tf_config['instance_type'] = {}
    instance_type_count = {}

    tf_config_json = AWSGenericHelper.get_terraform_config_json(tf_var_file)

    tf_config['region'] = tf_config_json['variable']['region']['default']
    tf_config['deploy_type'] = tf_config_json['variable']['azlist']['default']
    tf_config['storage-type'] = tf_config_json['variable']['storage-type']['default']
    tf_config['replica_count']['master'] = tf_config_json['variable']['master_replica_count']['default']
    tf_config['replica_count']['worker'] = tf_config_json['variable']['worker_replica_count']['default']
    tf_config['replica_count']['bootstrap'] = 1
    tf_config['replica_count']['bootnode'] = 1
    tf_config['instance_type']['master'] = tf_config_json['variable']['master-instance-type']['default']
    tf_config['instance_type']['worker'] = tf_config_json['variable']['worker-instance-type']['default']
    if tf_config['storage-type'] == 'ocs':
        tf_config['instance_type']['worker'] = tf_config_json['variable']['worker-ocs-instance-type']['default']
    tf_config['instance_type']['bootstrap'] = 'm4.large'
    tf_config['instance_type']['bootnode'] = tf_config_json['variable']['bootnode-instance-type']['default']

    # Summing up the number of required number of instance types
    for node_type in tf_config['instance_type']:
        instance_type = tf_config['instance_type'][node_type]
        if instance_type not in instance_type_count:
            instance_type_count[instance_type] = tf_config['replica_count'][node_type]
        else:
            instance_type_count[instance_type] += tf_config['replica_count'][node_type]

    tf_config['instances'] = instance_type_count

    # pprint(tf_config)

    return tf_config

def resource_validation_check(service_quotas, service_code, quota_code,
                              resources_used, resources_required):

    quota_value = 0.0
    # --> S3 Service Quoata: "L-DC2B2D3D" - "Buckets"
    #     since Buckets are tied to the Account
    if service_code == 's3' and quota_code == 'L-DC2B2D3D':
        quota_value = service_quotas[service_code][quota_code]['Value']
    else:
        quota_value = service_quotas[service_code][quota_code]['RegionValue']
    resources_available = quota_value - resources_used
    service_quotas[service_code][quota_code]['ResourcesAvailable'] = resources_available
    service_quotas[service_code][quota_code]['ResourcesRequired'] = resources_required
    service_quotas[service_code][quota_code]['ValidationCheck'] = 'PASSED'
    if resources_available < resources_required:
        service_quotas[service_code][quota_code]['ValidationCheck'] = 'FAILED'

def main():
    
    # Get resource related values from terraform config variables file
    tf_config = get_terraform_configuration()

    # Get the AWS configuration (credentials, region)
    aws_config = AWSConfigurationHelper.get_config(tf_config['region'])

    # Initialize AWS service client objects
    service_quota_helper = ServiceQuotasHelper(aws_config)
    ec2_helper = EC2Helper(aws_config)
    elb_helper = ELBHelper(aws_config)
    elb_v2_helper = ELBv2Helper(aws_config)
    s3_helper = S3Helper(aws_config)


    # Get / validate the Cluster High Availability config (single_zone / multi_zone)
    num_az = ec2_helper.get_num_availability_zones()
    ha_config = AWSConfigurationHelper.get_ha_config(num_az,
                                                     aws_config['region'],
                                                     ha_config = tf_config['deploy_type'])

    ####################
    #
    # Get service quotas
    #
    ####################

    # Service Quota dictionary used to hold all collected data
    sq = {}

    # VPC service quotas
    ## "L-FE5A380F" - "NAT gateways per Availability Zone"
    ## "L-E79EC296" - "VPC security groups per Region"
    ## "L-DF5E4CA3" - "Network interfaces per Region"
    ## "L-F678F1CE" - "VPCs per Region"
    vpc_quota_code_nat_gateways = 'L-FE5A380F'
    vpc_quota_code_security_groups = 'L-E79EC296'
    vpc_quota_code_network_interfaces = 'L-DF5E4CA3'
    vpc_quota_code_vpcs = 'L-F678F1CE'
    vpc_quota_codes = [vpc_quota_code_nat_gateways,
                       vpc_quota_code_security_groups,
                       vpc_quota_code_network_interfaces,
                       vpc_quota_code_vpcs]
    sq_vpc = service_quota_helper.get_quota('vpc', vpc_quota_codes, num_az = num_az)
    sq_vpc['vpc'][vpc_quota_code_nat_gateways]['Scope'] = 'Availability Zone'
    sq_vpc['vpc'][vpc_quota_code_security_groups]['Scope'] = 'Region'
    sq_vpc['vpc'][vpc_quota_code_network_interfaces]['Scope'] = 'Region'
    sq_vpc['vpc'][vpc_quota_code_vpcs]['Scope'] = 'Region'
    for quota_code in vpc_quota_codes:
        sq_vpc['vpc'][quota_code]['DisplayServiceCode'] = 'VPC'

    sq.update(sq_vpc)

    # EC2 service quotas
    ## "L-0263D0A3" - "EC2-VPC Elastic IPs"
    ## "L-74FC7D96" - "Running On-Demand F instances"
    ## "L-DB2E81BA" - "Running On-Demand G instances"
    ## "L-1945791B" - "Running On-Demand Inf instances"
    ## "L-417A185B" - "Running On-Demand P instances"
    ## "L-1216C47A" - "Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances"
    ## "L-7295265B" - "Running On-Demand X instances"
    ec2_quota_code_elastic_ips = 'L-0263D0A3'
    ec2_quota_code_instances_f = 'L-74FC7D96'
    ec2_quota_code_instances_g = 'L-DB2E81BA'
    ec2_quota_code_instances_inf = 'L-1945791B'
    ec2_quota_code_instances_p = 'L-417A185B'
    ec2_quota_code_instances_standard = 'L-1216C47A'
    ec2_quota_code_instances_x = 'L-7295265B'
    ec2_quota_codes = [ec2_quota_code_elastic_ips,
                       ec2_quota_code_instances_f,
                       ec2_quota_code_instances_g,
                       ec2_quota_code_instances_inf,
                       ec2_quota_code_instances_p,
                       ec2_quota_code_instances_standard,
                       ec2_quota_code_instances_x]
    sq_ec2 = service_quota_helper.get_quota('ec2', ec2_quota_codes)
    for quota_code in ec2_quota_codes:
        sq_ec2['ec2'][quota_code]['Scope'] = 'Region'
    for quota_code in ec2_quota_codes:
        sq_ec2['ec2'][quota_code]['DisplayServiceCode'] = 'EC2'

    sq.update(sq_ec2)

    # Elastic Load Balancing service quotas
    ## "L-53DA6B97" - "Application Load Balancers per Region"
    ## "L-E9E9831D" - "Classic Load Balancers per Region"
    elb_quota_code_application_load_balancers = 'L-53DA6B97'
    elb_quota_code_classic_load_balancers = 'L-E9E9831D'
    elb_quota_codes = [elb_quota_code_application_load_balancers,
                       elb_quota_code_classic_load_balancers]
    sq_elb = service_quota_helper.get_quota('elasticloadbalancing', elb_quota_codes)
    for quota_code in elb_quota_codes:
        sq_elb['elasticloadbalancing'][quota_code]['Scope'] = 'Region'
    for quota_code in elb_quota_codes:
        sq_elb['elasticloadbalancing'][quota_code]['DisplayServiceCode'] = 'ELB'

    sq.update(sq_elb)

    # S3 service quotas
    ## "L-DC2B2D3D" - "Buckets"
    s3_quota_code_buckets = 'L-DC2B2D3D'
    s3_quota_codes = [s3_quota_code_buckets]
    sq_s3 = service_quota_helper.get_quota('s3', s3_quota_codes)
    sq_s3['s3'][s3_quota_code_buckets]['Scope'] = 'Account'
    # Since Buckets are tied to the Account - need to unset 'RegionValue'
    sq_s3['s3'][s3_quota_code_buckets]['RegionValue'] = ''
    for quota_code in s3_quota_codes:
        sq_s3['s3'][quota_code]['DisplayServiceCode'] = 'S3'

    sq.update(sq_s3)

    # VPC Gateway - service quotas
    ## To be done

    ##############################
    #
    # Get resource usage counts  +
    # Add required resource counts
    #
    ##############################
   
    # EC2 resources
    ## VPCs
    vpc_used = ec2_helper.get_num_vpc()
    vpc_required = ocp[ocp_version][ha_config]['vpcs']
    resource_validation_check(sq, 'vpc', vpc_quota_code_vpcs,
                              vpc_used, vpc_required)

    ### Elastic IPs
    eip_used = ec2_helper.get_num_elastic_ips()
    eip_required = ocp[ocp_version][ha_config]['elastic-ips']
    resource_validation_check(sq, 'ec2', ec2_quota_code_elastic_ips,
                              eip_used, eip_required)

    ### NatGateways
    nat_gw_used = ec2_helper.get_num_nat_gw()
    nat_gw_required = ocp[ocp_version][ha_config]['nat-gateways']
    resource_validation_check(sq, 'vpc', vpc_quota_code_nat_gateways,
                              nat_gw_used, nat_gw_required)

    ### SecurityGroups
    sg_used = ec2_helper.get_num_security_groups()
    sg_required = ocp[ocp_version][ha_config]['security-groups']
    resource_validation_check(sq, 'vpc', vpc_quota_code_security_groups,
                              sg_used, sg_required)


    ### Elastic Network Interfaces (ENIs)
    eni_used = ec2_helper.get_num_network_interfaces()
    eni_required = ocp[ocp_version][ha_config]['network-interfaces']
    resource_validation_check(sq, 'vpc', vpc_quota_code_network_interfaces,
                              eni_used, eni_required)

    ### Instances
    instances_vcpus_used = ec2_helper.get_instances_num_vcpus_used()
    instances_vcpus_required = ec2_helper.get_instances_num_vcpus(tf_config['instances'])
    resource_validation_check(sq, 'ec2', ec2_quota_code_instances_f,
                              instances_vcpus_used['f'],
                              instances_vcpus_required['f'])
    resource_validation_check(sq, 'ec2', ec2_quota_code_instances_g,
                              instances_vcpus_used['g'],
                              instances_vcpus_required['g'])
    resource_validation_check(sq, 'ec2', ec2_quota_code_instances_inf,
                              instances_vcpus_used['inf'],
                              instances_vcpus_required['inf'])
    resource_validation_check(sq, 'ec2', ec2_quota_code_instances_p,
                              instances_vcpus_used['p'],
                              instances_vcpus_required['p'])
    resource_validation_check(sq, 'ec2', ec2_quota_code_instances_standard,
                              instances_vcpus_used['standard'],
                              instances_vcpus_required['standard'])
    resource_validation_check(sq, 'ec2', ec2_quota_code_instances_x,
                              instances_vcpus_used['x'],
                              instances_vcpus_required['x'])

    ## ELB v2 (network) resouces usage counts
    ### Elastic Load Balancers v2 (ELB/NLB) - type: network
    elb_v2_used = elb_v2_helper.get_num_elb_v2()
    elb_v2_required = ocp[ocp_version][ha_config]['application-load-ballancer']
    resource_validation_check(sq, 'elasticloadbalancing',
                              elb_quota_code_application_load_balancers,
                              elb_v2_used, elb_v2_required)

    ## ELB (classic) resouces usage counts
    ### Elastic Load Balancers (ELB/NLB) - type: classic
    elb_used = elb_helper.get_num_elb()
    elb_required = ocp[ocp_version][ha_config]['classic-load-ballancer']
    resource_validation_check(sq, 'elasticloadbalancing',
                              elb_quota_code_classic_load_balancers,
                              elb_used, elb_required)

    ## S3 resouces usage counts
    ### S3 buckets
    s3_buckets_used = s3_helper.get_num_buckets()
    s3_required = ocp[ocp_version][ha_config]['s3-buckets']
    resource_validation_check(sq, 's3', s3_quota_code_buckets,
                              s3_buckets_used, s3_required)

    print('\nService quotas + currently used resources:')
    print('==========================================\n')

    print(f"  AWS Region                                  : {aws_config['region']}")
    print(f"  Number of Availability Zones in that region : {num_az}")
    print(f"  Desired HA config                           : {ha_config}\n")

    # pprint(sq)

    # Table column width
    width_column_1 = 8
    width_column_2 = 65
    width_column_3 = 18
    width_column_4 = 6
    width_column_5 = 15
    width_column_6 = 20
    width_column_7 = 19
    width_column_8 = 18

    # Tabel header format
    table_header_format = (
        "  {col_1:<{col_1_width}}|" +
        " {col_2:<{col_2_width}} |" +
        " {col_3:<{col_3_width}} |" +
        " {col_4:<{col_4_width}} |" +
        " {col_5:<{col_5_width}} |" +
        " {col_6:<{col_6_width}} |" +
        " {col_7:<{col_7_width}} |" +
        " {col_8:<{col_8_width}}"
    )

    # Tabel row separator format
    table_row_separator_format = (
        "  {col_1:{col_1_width}}|" +
        "{col_2:{col_2_width}}|" +
        "{col_3:{col_3_width}}|" +
        "{col_4:{col_4_width}}|" +
        "{col_5:{col_5_width}}|" +
        "{col_6:{col_6_width}}|" +
        "{col_7:{col_7_width}}|" +
        "{col_8:{col_8_width}}"
    )

    # Table row format
    table_row_format = (
        "   {col_1:<{col_1_width}}|" +
        "  {col_2:<{col_2_width}}|" +
        "  {col_3:<{col_3_width}}|" +
        "  {col_4:<{col_4_width}}|" +
        "  {col_5:>{col_5_width}} |" +
        "  {col_6:>{col_6_width}} |" +
        "  {col_7:>{col_7_width}} |" +
        "  {col_8:{col_8_width}}"
    )

    # Table header
    table_header = (table_header_format.format(
        col_1="Service", col_1_width=width_column_1,
        col_2="Service Quota Name", col_2_width=width_column_2,
        col_3="Scope", col_3_width=width_column_3,
        col_4="Unit", col_4_width=width_column_4,
        col_5="Service Quotas", col_5_width=width_column_5,
        col_6="Resources available", col_6_width=width_column_6,
        col_7="Resources required", col_7_width=width_column_7,
        col_8="Validation check", col_8_width=width_column_8)
    )

    # Table row separator
    table_row_separator = (table_row_separator_format.format(
        col_1="-"*width_column_1, col_1_width=width_column_1,
        col_2="-"*(width_column_2 + 2), col_2_width=width_column_2 + 2,
        col_3="-"*(width_column_3 + 2), col_3_width=width_column_3 + 2,
        col_4="-"*(width_column_4 + 2), col_4_width=width_column_4 + 2,
        col_5="-"*(width_column_5 + 2), col_5_width=width_column_5 + 2,
        col_6="-"*(width_column_6 + 2), col_6_width=width_column_6 + 2,
        col_7="-"*(width_column_7 + 2), col_7_width=width_column_7 + 2,
        col_8="-"*width_column_8, col_8_width=width_column_8)
    )

    # Table - print out
    print(table_header)

    print_validation_check_failed_comment = False
    for key in sq:
        print(table_row_separator)
        for item in sq[key]:
            if sq[key][item]['ValidationCheck'] == 'FAILED':
                print_validation_check_failed_comment = True
            print(table_row_format.format(
                col_1=sq[key][item]['DisplayServiceCode'], col_1_width=width_column_1 - 1,
                col_2=sq[key][item]['QuotaName'], col_2_width=width_column_2,
                col_3=sq[key][item]['Scope'], col_3_width=width_column_3,
                col_4=sq[key][item]['Unit'], col_4_width=width_column_4,
                col_5=sq[key][item]['Value'], col_5_width=width_column_5 - 1,
                col_6=sq[key][item]['ResourcesAvailable'], col_6_width=width_column_6 - 1,
                col_7=sq[key][item]['ResourcesRequired'], col_7_width=width_column_7 - 1,
                col_8=sq[key][item]['ValidationCheck'], col_8_width=width_column_8)
            )

    print("\n")
    print("Comments")
    print("========")
    if print_validation_check_failed_comment:
        print("  * Validation check = 'FAILED'")
        print("    There are not enough resources available to create the desired infrastructure in that region.")
        print("    Recommendation:")
        print("      - Cleanup resources in that region.")
        print("      - Specify a different region.")
    else:
        print("\n  * Validation check = 'PASSED'")
        print("    Cluster can be created in that region.")
    print("")

if __name__ == '__main__':
    sys.exit(main())
