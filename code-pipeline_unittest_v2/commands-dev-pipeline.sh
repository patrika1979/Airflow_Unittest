# Create the S3 bucket for the CodePipeline artifacts - This bucket must be globally unique so set your own
aws s3 mb s3://cdt-dev-codepipeline-artifacts

#create admin role to be assumed by Cloud9
aws iam create-role --role-name Cloud9Admin --assume-role-policy-document file://cpAssumeRolePolicyDocumentAdmin
aws iam create-instance-profile --instance-profile-name ec2Admin
aws iam add-role-to-instance-profile --instance-profile-name ec2Admin --role-name Cloud9Admin
aws ec2 associate-iam-instance-profile --iam-instance-profile Name=ec2Admin --instance-id $(aws ec2 describe-instances --filters \
"Name=tag:Environment,Values=AWS Example" | jq .Reservations[0].Instances[0].InstanceId) | awk '{print $1}' | tr -d \"


#create cloud9
aws cloudformation deploy --stack-name cloud9 --template-file cloud9.yml --capabilities CAPABILITY_NAMED_IAM

#attach role 
aws iam attach-role-policy --role-name Cloud9Admin #--policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create IAM roles and add iniline policies so that CodePipeline can interact with EKS through kubectl
aws iam create-role --role-name AirflowCodePipelineServiceRole --assume-role-policy-document file://code-pipeline_unittest/cpAssumeRolePolicyDocument.json
aws iam put-role-policy --role-name AirflowCodePipelineServiceRole --policy-name codepipeline-access --policy-document file://code-pipeline_unittest/cpPolicyDocument.json
aws iam create-role --role-name AirflowCodeBuildServiceRole --assume-role-policy-document file://code-pipeline_unittest/cbAssumeRolePolicyDocument.json
aws iam put-role-policy --role-name AirflowCodeBuildServiceRole --policy-name codebuild-access --policy-document file://code-pipeline_unittest/cbPolicyDocument.json

# open the flux pipeline to set the bucket name you created under "ArtifactStore"
vim airflow-materials-aws/code-pipeline/airflow-dev-pipeline.cfn.yml

# Create the AWS CodePipeline using CloudFormation (This doesn't deploy the image as Flux handles it)
#aws cloudformation create-stack --stack-name=airflow-dev-pipeline --template-body=file://airflow-materials-aws/section-6/code-pipeline/airflow-dev-pipeline.cfn.yml --parameters ParameterKey=GitHubUser,ParameterValue=marclamberti ParameterKey=GitHubToken,ParameterValue=cb53803446b0968e132e2e8ff729c7596fb0d7c8 ParameterKey=GitSourceRepo,ParameterValue=airflow-eks-docker ParameterKey=GitBranch,ParameterValue=dev

#Run Cloduformation template with Parameters
aws cloudformation create-stack --stack-name=airflow-dev-pipeline --template-body=file://airflow-dev-pipeline.cfn.yml --parameters=file://parameters.json --region=us-east-1

#delete stack
aws cloudformation delete-stack --stack-name airflow-dev-pipeline

#update the pipeline
aws cloudformation update-stack --stack-name=airflow-dev-pipeline --template-body=file://airflow-dev-pipeline.cfn.yml --parameters=file://parameters.json --region=us-east-1
