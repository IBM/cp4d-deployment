import boto3
import boto3.session

from botocore.exceptions import ClientError

import hcl
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

    # parse terraform config
    @staticmethod
    def get_terraform_config_json(terraform_var_file):

        try:
            with open(terraform_var_file, 'r') as f:
                tf_config_json = hcl.load(f)
            return tf_config_json
        except IOError as e:
            # print(e)
            print("ERROR: The terraform variables file " +
                  f"'{terraform_var_file}' was not found.")
            exit(1)
