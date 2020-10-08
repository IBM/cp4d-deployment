import boto3
import boto3.session

from botocore.exceptions import ClientError

import logging


class AWSGenericHelper():
    '''
    Object used to:
    - create a session object
    - further generic AWS methods to be used by other modules
    '''

    def __init__(self, aws_config):
        self._aws_config = aws_config

    # Create an AWS session
    def create_session(self):

        try:
            aws_session = boto3.session.Session(
                aws_access_key_id = self._aws_config['access_key'],
                aws_secret_access_key = self._aws_config['secret_access_key'],
                region_name = self._aws_config['region']
            )
            return aws_session
        except ClientError as e:
            # logging.error(e)
            print("  * The AWS session could not be created.")
            print('  * Please, try again.')
            exit(1)

