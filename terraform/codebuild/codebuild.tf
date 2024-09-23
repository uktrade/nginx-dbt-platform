resource "aws_codebuild_project" "project" {
  name                   = var.project_name
  badge_enabled          = true
  description            = var.project_description
  service_role           = aws_iam_role.codebuild_service_role.arn
  source_version         = var.github.branch
  build_timeout          = var.build_timeout
  concurrent_build_limit = var.concurrent_build_limit

  source {
    type                = "GITHUB"
    location            = var.github.repository
    buildspec           = var.github.buildspec
    git_clone_depth     = 1
    report_build_status = true
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    modes = var.cache.modes
    type  = var.cache.type
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = var.environment_image
    image_pull_credentials_type = var.environment_image_pull_credentials_type
    type                        = var.environment_type
    # checkov:skip=CKV_AWS_316:CodeBuild project requires access to Docker daemon
    privileged_mode = var.privileged_mode

    dynamic "environment_variable" {
      for_each = merge(
        { AWS_ACCOUNT_ID : data.aws_caller_identity.current.account_id },
        var.environment_variables
      )

      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_log_group.name
      stream_name = aws_cloudwatch_log_stream.codebuild_log_stream.name
    }
  }
}

resource "aws_codebuild_webhook" "github" {
  project_name = aws_codebuild_project.project.name
  count        = var.enable_webhook ? 1 : 0
  build_type   = "BUILD"

  dynamic "filter_group" {
    for_each = var.webhook_filters

    content {
      dynamic "filter" {
        for_each = filter_group.value

        content {
          type    = filter.value.type
          pattern = filter.value.pattern
        }
      }
    }
  }
}
