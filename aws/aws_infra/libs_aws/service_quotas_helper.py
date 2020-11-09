import boto3

from botocore.exceptions import ClientError
from libs_aws.aws_generic_helper import AWSGenericHelper

import logging
import re


class ServiceQuotasHelper():
    '''
    Object used to access the AWS Service Quota service to retrieve
    service quotas (limits) for the AWS account
    '''

    def __init__(self, aws_config):
        self.__service_quotas_session = self.__create_client_session(
                                                                aws_config)

    def __create_client_session(self, aws_config):

        # Create an AWS session client
        try:
            session_helper = AWSGenericHelper(aws_config)
            aws_session = session_helper.create_session()
            service_quotas_session = aws_session.client('service-quotas')
            return service_quotas_session
        except ClientError as e:
            # logging.error(e)
            print("  * The AWS client could not be created.")
            print('  * Please, try again.')
            exit(1)


    def list_service_quotas(self, service_code):

        service_quotas = []

        # Create a reusable Paginator
        paginator = self.__service_quotas_session.get_paginator(
            'list_service_quotas'
        )

        # Create a PageIterator from the Paginator
        page_iterator = paginator.paginate(ServiceCode=service_code)

        for page in page_iterator:
            service_quotas = service_quotas + page['Quotas']

        return service_quotas

    def list_aws_default_service_quotas(self, service_code):

        aws_default_service_quotas = []

        # Create a reusable Paginator
        paginator = self.__service_quotas_session.get_paginator(
            'list_aws_default_service_quotas'
        )

        # Create a PageIterator from the Paginator
        page_iterator = paginator.paginate(ServiceCode=service_code)

        for page in page_iterator:
            aws_default_service_quotas = ( aws_default_service_quotas +
                                           page['Quotas'] )

        return aws_default_service_quotas


    def _retrieve_quota(self, service_code, quota_codes, service_quotas,
                        num_az = None):
        quota = {}
        quota[service_code] = {}

        for svc_quota in service_quotas:
            svc_quota_code = svc_quota['QuotaCode']
            q = {}
            if svc_quota_code in quota_codes:
                q[svc_quota_code] = {}
                q[svc_quota_code]['QuotaSource'] = 'service quotas'
                q[svc_quota_code]['QuotaCode'] = svc_quota['QuotaCode']
                q[svc_quota_code]['QuotaName'] = svc_quota['QuotaName']
                q[svc_quota_code]['ServiceCode'] = svc_quota['ServiceCode']
                q[svc_quota_code]['Value'] = svc_quota['Value']

                # Service Quota 'RegionValue'
                # multiply values for QuotaCodes that are tied to Availability Zone by
                # the number of Availability Zones in that Region
                # here: "L-FE5A380F" - "NAT gateways per Availability Zone"
                if svc_quota['QuotaCode'] == 'L-FE5A380F':
                    q[svc_quota_code]['RegionValue'] = svc_quota['Value'] * num_az
                else:
                    q[svc_quota_code]['RegionValue'] = svc_quota['Value']

                # Service Quota 'Unit'
                if re.search(r'Running On-Demand .* instances',
                                svc_quota['QuotaName']):
                    q[svc_quota_code]['Unit'] = 'vCPUs'
                elif svc_quota['Unit'] == 'None':
                    q[svc_quota_code]['Unit'] = 'count'
                else:
                    q[svc_quota_code]['Unit'] = svc_quota['Unit']
                quota[service_code].update(q)

        return quota



    def get_quota(self, service_code, quota_codes, num_az = None):
        quota = {}

        # Get applied quota values
        service_quotas = self.list_service_quotas(service_code)

        # Get AWS default quota values
        aws_default_service_quotas = self.list_aws_default_service_quotas(
                                                                service_code)

        for quota_code in quota_codes:
            if any(svc_quota['QuotaCode'] == quota_code
                   for svc_quota in service_quotas):
                quota = self._retrieve_quota(service_code,
                                             quota_codes,
                                             service_quotas,
                                             num_az = num_az)
            else:
                quota = self._retrieve_quota(service_code,
                                             quota_codes,
                                             aws_default_service_quotas,
                                             num_az = num_az)

        return quota
