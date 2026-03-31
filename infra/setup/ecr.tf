##############################################################################################
# Create ECR repos for storing Docker images                                                 #
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository #
##############################################################################################

resource "aws_ecr_repository" "app" {
  name                 = "repo-py-app"
  image_tag_mutability = "MUTABLE" # allow to have latest tag
  force_delete         = true      # delete repo if it already exists when calling terraform destroy

  image_scanning_configuration {
    # NOTE: Update to true for real deployments.
    scan_on_push = false
  }
}

resource "aws_ecr_repository" "proxy" {
  name                 = "repo-py-app-proxy"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    # NOTE: Update to true for real deployments.
    scan_on_push = false
  }
}

###########################################################################
# Policy for ECR access                                                   #
# https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push.html  #
###########################################################################

data "aws_iam_policy_document" "ecr" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
    resources = [
      aws_ecr_repository.app.arn,   # dinamically get the arn from the app aws_ecr_repository from line 6
      aws_ecr_repository.proxy.arn, # dinamically get the arn from the app aws_ecr_repository from line 17
    ]
  }
}

resource "aws_iam_policy" "ecr" {
  name        = "${aws_iam_user.cd.name}-ecr"
  description = "Allow user to manage ECR resources"
  policy      = data.aws_iam_policy_document.ecr.json
}

resource "aws_iam_user_policy_attachment" "ecr" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.ecr.arn
}