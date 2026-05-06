terraform {
  required_version = ">= 1.6.0"

  # Uncomment AFTER creating the S3 bucket + DynamoDB table
   backend "s3" {
   bucket         = "biswajit-tfstate-ap-south-1"
   key            = "app/terraform.tfstate"
   region         = "ap-south-1"
   dynamodb_table = "terraform-locks"
   encrypt        = true
  }
}