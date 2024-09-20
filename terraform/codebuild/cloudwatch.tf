locals {
  log_group_name = "codebuild/${var.project_name}/log-group"
}

resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name       = local.log_group_name
  kms_key_id = aws_kms_key.cloudwatch.arn
  # checkov:skip=CKV_AWS_338:Retains logs for 3 months instead of 1 year
  retention_in_days = 90

  depends_on = [aws_kms_key_policy.cloudwatch]
}

resource "aws_cloudwatch_log_stream" "codebuild_log_stream" {
  name           = "codebuild/${var.project_name}/log-stream"
  log_group_name = aws_cloudwatch_log_group.codebuild_log_group.name
}

resource "aws_kms_key" "cloudwatch" {
  description         = "CloudWatch Log Group KMS Key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${var.project_name}-cloudwatch-log-group-cmk"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

resource "aws_kms_key_policy" "cloudwatch" {
  key_id = aws_kms_key.cloudwatch.id
  policy = jsonencode({
    Id = "CloudWatch Logs group KMS key policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Resource = "*"
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "logs.eu-west-2.amazonaws.com"
        },
        "Action" : [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ],
        "Resource" : "*",
        "Condition" : {
          "ArnLike" : {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}
