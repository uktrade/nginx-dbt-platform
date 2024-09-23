resource "aws_scheduler_schedule" "codebuild" {
  # checkov:skip=CKV_AWS_297:EventBridge Scheduler uses AWS owned keys by default
  name                = var.schedule_name
  description         = var.schedule_description
  schedule_expression = var.schedule_expression
  count               = var.enable_scheduler ? 1 : 0

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_codebuild_project.project.arn
    role_arn = aws_iam_role.codebuild_service_role.arn
  }
}
