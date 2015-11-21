#!/bin/bash
echo "Starting cleanup."

# Check if jq is in the PATH
found=$(which jq)
if [ -z "$found" ]; then
  echo "Please install jq under your PATH: http://stedolan.github.io/jq/"
  exit 1
fi

# Ensure config.json exists
if [ ! -f config.json ]; then
	echo "config.json not found!"
	exit 1
fi

# Get config parmaters
echo "Loading config parameters"
# Read other configuration from config.json
AWS_ACCOUNT_ID=$(jq -r '.AWS_ACCOUNT_ID' config.json)
CLI_PROFILE=$(jq -r '.CLI_PROFILE' config.json)
REGION=$(jq -r '.REGION' config.json)
BUCKET=$(jq -r '.BUCKET' config.json)
MAX_AGE=$(jq -r '.MAX_AGE' config.json)
DDB_TABLE=$(jq -r '.DDB_TABLE' config.json)
TEACHER_TABLE=$(jq -r '.TEACHER_TABLE' config.json)
CREW_TABLE=$(jq -r '.CREW_TABLE' config.json)
STUDENT_TABLE=$(jq -r '.STUDENT_TABLE' config.json)
IDENTITY_POOL_NAME=$(jq -r '.IDENTITY_POOL_NAME' config.json)
IDENTITY_POOL_ID=$(jq -r '.IDENTITY_POOL_ID' config.json)
DEVELOPER_PROVIDER_NAME=$(jq -r '.DEVELOPER_PROVIDER_NAME' config.json)

if [  -z "$REGION"  ]; then
	echo "config.json: REGION value is required, but missing!"
	exit 1
fi
if [  -z "$BUCKET"  ]; then
	echo "config.json: BUCKET value is required, but missing!"
	exit 1
fi

#if a CLI Profile name is provided... use it.
if [[ ! -z "$CLI_PROFILE" ]]; then
  echo "setting session CLI profile to $CLI_PROFILE"
  export AWS_DEFAULT_PROFILE=$CLI_PROFILE
fi

# Remove IAM Roles Created for Lambda functions and Cognito
for f in $(ls -1|grep ^LambdAuth); do
  echo "Deleting IAM Role and Policy for: $f"
  aws iam delete-role-policy --role-name "$f" --policy-name $f
  aws iam delete-role --role-name "$f"
done

# Remove Cognito Identity Pool
echo "Removing Cognito Identity Pool"
aws cognito-identity delete-identity-pool --identity-pool-id $IDENTITY_POOL_ID --region $REGION
mv config.json config.json.orig
jq '.IDENTITY_POOL_ID=""' config.json.orig > config.json
rm config.json.orig

# Remove dynamodb Table
echo "Removing DynamoDB table"
aws dynamodb delete-table --table-name "$DDB_TABLE" --region $REGION

# Remove the S3 Bucket
echo "Removing S3 Bucket"
aws s3 rm s3://$BUCKET --recursive
aws s3 rb s3://$BUCKET --force

# Remove Lambda functions
echo "Removing Lambda functions..."
for f in $(ls -1|grep ^LambdAuth); do
  echo "Deleting Lambda function: $f"
  aws lambda delete-function --function-name "$f" --region $REGION
done

# Remove CloudWatch Logs and Streams
for f in $(aws logs describe-log-groups --region $REGION | jq -r '.logGroups[] | select(.logGroupName | contains("LambdAuth")) .logGroupName'); do
	echo "Deleting Log group: $f"
	aws logs delete-log-group --log-group-name "$f" --region $REGION
done

echo "Cleanup complete."
