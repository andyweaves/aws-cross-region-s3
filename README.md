# aws-cross-region-s3

## Cross Region Access from Databricks to S3 based on [AWS recommended architecture](https://repost.aws/knowledge-center/vpc-endpoints-cross-region-aws-services)

![image](https://github.com/andyweaves/aws-cross-region-s3/assets/43955924/5a0b5388-4756-49c2-ba84-6c1e6b010603)

## Deployment Steps

1. Install Terraform
2. Update [terraform.tfvars](terraform.tfvars)
3. Setup Terraform to use your AWS credentials
4. Run Terraform init
5. Run Terraform plan, entering your Databricks account credentials
6. Run Terraform apply, entering your Databricks account credentials

## Test Steps

1. Login to your new Databricks workspace
2. Create a new cluster (recommended to use the latest DBR version). Ensure that you have selected the instance profile created by Terraform
3. Navigate to the notebook created by Terraform (in Workspace > Shared > test_notebook.py)
4. Update the s3_bucket_name and region_name variables
5. Run the notebook

## Limitations

* Most of the above is based on DNS overrides and Spark configuration that may not be compatible with all Databricks features. Ideally AWS would allow for managed private DNS for AWS S3, including from other regions.
