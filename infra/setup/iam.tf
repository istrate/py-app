#########################################################################################
# Create IAM user and policies for Continuous Deployment (CD) account                   #
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user  #
#########################################################################################

# cd is the name of the resource, in thi case aws_iam_user
resource "aws_iam_user" "cd" {
  name = "app-cd"
}
# create access key for the cd user
resource "aws_iam_access_key" "cd" {
  user = aws_iam_user.cd.name
}

#############################################################################################
# Policy for Teraform backend to S3 and DynamoDB access                                     #
# https://developer.hashicorp.com/terraform/language/backend/s3#s3-bucket-permissions       #
# https://developer.hashicorp.com/terraform/language/backend/s3#dynamodb-table-permissions  #
# https://developer.hashicorp.com/terraform/language/values/outputs                         #
#############################################################################################

data "aws_iam_policy_document" "tf_backend" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"] #
    resources = ["arn:aws:s3:::${var.tf_state_bucket}"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}/tf-state-deploy/*",
      "arn:aws:s3:::${var.tf_state_bucket}/tf-state-deploy-env/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.tf_state_lock_table}"]
  }
}

resource "aws_iam_policy" "tf_backend" {
  name        = "${aws_iam_user.cd.name}-tf-s3-dynamodb"
  description = "Allow user to use S3 and DynamoDB for TF backend resources"
  policy      = data.aws_iam_policy_document.tf_backend.json
}

resource "aws_iam_user_policy_attachment" "tf_backend" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.tf_backend.arn
}