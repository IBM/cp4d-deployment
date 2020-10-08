import boto3

from botocore.exceptions import ClientError
from libs_aws.aws_generic_helper import AWSGenericHelper

import logging

from pprint import pprint

class EC2Helper():
    '''
    Object used to access the AWS EC2 service
    '''

    def __init__(self, aws_config):
        self.__ec2_session = self.__create_client_session(aws_config)

    def __create_client_session(self, aws_config):

        # Create an AWS session client
        try:
            session_helper = AWSGenericHelper(aws_config)
            aws_session = session_helper.create_session()
            ec2_session = aws_session.client('ec2')
            return ec2_session
        except ClientError as e:
            # logging.error(e)
            print("  * The AWS client could not be created.")
            print('  * Please, try again.')
            exit(1)

    # describe paginated resources
    def describe_resource(self, operation_name, object_key):
        resource = []

        # Create a reusable Paginator
        paginator = self.__ec2_session.get_paginator(operation_name)

        # Create a PageIterator from the Paginator
        page_iterator = paginator.paginate()

        for page in page_iterator:
            resource = resource + page[object_key]

        return resource

    def get_num_vpc(self):
        vpc = self.describe_resource('describe_vpcs',
                                      'Vpcs')
        vpc_in_use = len(vpc)
        return vpc_in_use

    def get_num_nat_gw(self):
        nat_gw = self.describe_resource('describe_nat_gateways',
                                         'NatGateways')
        nat_gw_in_use = len(nat_gw)
        return nat_gw_in_use

    def get_num_security_groups(self):
        sg = self.describe_resource('describe_security_groups',
                                     'SecurityGroups')
        sg_in_use = len(sg)
        return sg_in_use

    def get_num_network_interfaces(self):
        ni = self.describe_resource('describe_network_interfaces',
                                     'NetworkInterfaces')
        ni_in_use = len(ni)
        return ni_in_use

    def get_num_instances_per_type(self):
        instances = []
        instance_type_count = {}

        reservations = self.describe_resource('describe_instances',
                                              'Reservations')

        for item in reservations:
            instances += item['Instances']

        for instance in instances:
            instance_type = instance['InstanceType']
            if instance_type not in instance_type_count:
                instance_type_count[instance_type] = 1
            else:
                instance_type_count[instance_type] += 1

        return instance_type_count

    def get_vcpus_per_instance_type(self):
        instance_type_vcpu_count = {}

        instance_types = self.describe_resource(
                            'describe_instance_types',
                            'InstanceTypes')

        for item in instance_types:
            instance_type = item['InstanceType']
            vcpus = item['VCpuInfo']['DefaultVCpus']
            instance_type_vcpu_count[instance_type] = vcpus

        return instance_type_vcpu_count

    def get_instances_num_vcpus(self, instance_type_count):
        '''
        Get the number of vCPUs per instance group for the 
        specified 'instance_type_count'.
        (e.g.: per F instance, G instance, Standard instance, etc.)

        Parameters:
        - instance_type_count = dictionary
                                * key: instance_type
                                * value: num instance_types

        Returns:
        - instances_num_vcpus_used = dictionary 
                                     * key: instance_group
                                     * value: num_vcpus
        '''
        all_instances_vcpus = {}
        instances_num_vcpus = {
            'f': 0,
            'g': 0,
            'inf': 0,
            'p': 0,
            'standard': 0,
            'x': 0
        }
        standard_instance = ['a', 'c', 'd', 'h', 'i', 'm', 'r', 't', 'z']

        instance_type_vcpu_count = self.get_vcpus_per_instance_type()

        for instance_type in instance_type_count:
            all_instances_vcpus[instance_type] = (
                instance_type_count[instance_type] *
                instance_type_vcpu_count[instance_type]
            )

        for instance_group in instances_num_vcpus:
            for key, value in all_instances_vcpus.items():
                if instance_group == 'standard':
                    for item in standard_instance:
                        if key.startswith(item):
                            instances_num_vcpus[instance_group] += value
                else:
                    if key.startswith(instance_group):
                        instances_num_vcpus[instance_group] += value

        return instances_num_vcpus

    
    def get_instances_num_vcpus_used(self):
        '''
        Get the number of vCPUs used per instance group.
        (e.g.: per F instance, G instance, Standard instance, etc.)

        Returns:
        instances_num_vcpus_used = dictionary 
                                    * key: instance_group
                                    * value: num_vcpus
        '''
        instance_type_count_used = self.get_num_instances_per_type()
        instances_num_vcpus_used = self.get_instances_num_vcpus(
                                                    instance_type_count_used)
        return instances_num_vcpus_used

    # describe not paginated resources
    def describe_addresses(self):
        addresses = self.__ec2_session.describe_addresses()
        return addresses['Addresses']

    def get_num_elastic_ips(self):
        eip = self.describe_addresses()
        return len(eip)

    def describe_availability_zones(self):
        az = self.__ec2_session.describe_availability_zones()
        return az['AvailabilityZones']

    def get_num_availability_zones(self):
        az = self.describe_availability_zones()
        return len(az)

