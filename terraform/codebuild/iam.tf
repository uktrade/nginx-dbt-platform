data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "codebuild.amazonaws.com",
        "scheduler.amazonaws.com"
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild_service_role" {
  name               = "codebuild-${var.project_name}-service-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "codebuild_base_policy" {
  statement {
    sid    = "CodeBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild"
    ]
    resources = [
      aws_codebuild_project.project.arn
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.codebuild_log_group.arn,
      "${aws_cloudwatch_log_group.codebuild_log_group.arn}:*"
    ]
  }

  statement {
    sid    = "ParameterStore"
    effect = "Allow"
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/pypi-token"
    ]
  }
  statement {
    sid    = "SSMSession"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild_service_role_inline_policy" {
  name   = "CodeBuildBasePolicy"
  role   = aws_iam_role.codebuild_service_role.name
  policy = data.aws_iam_policy_document.codebuild_base_policy.json
}

resource "aws_iam_role_policy_attachment" "codebuild_role_policy_attach" {
  for_each = var.attached_policies

  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = each.value
}
