variable "enable_scheduler" {
  description = "Enable/disable EventBridge Scheduler schedule."
  type        = bool
}

variable "enable_webhook" {
  description = "Enable/disable CodeBuild webhook."
  type        = bool
}

variable "environment_image" {
  description = "Docker image to use for the CodeBuild project."
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
  type        = string
}

variable "environment_image_pull_credentials_type" {
  description = "Type of credentials AWS CodeBuild uses to pull images."
  default     = "CODEBUILD"
  type        = string

  validation {
    condition     = contains(["CODEBUILD", "SERVICE_ROLE"], var.environment_image_pull_credentials_type)
    error_message = "Allowed values for environment_image_pull_credentials_type are \"CODEBUILD\", or \"SERVICE_ROLE\"."
  }
}

variable "environment_type" {
  description = "Type of build environment to use."
  default     = "LINUX_CONTAINER"
  type        = string

  validation {
    condition = contains([
      "LINUX_CONTAINER", "LINUX_GPU_CONTAINER", "WINDOWS_SERVER_2019_CONTAINER", "ARM_CONTAINER"
    ], var.environment_type)
    error_message = "Allowed values for environment_type are \"LINUX_CONTAINER\", \"LINUX_GPU_CONTAINER\", \"WINDOWS_SERVER_2019_CONTAINER\", or \"c\"."
  }
}

variable "environment_variables" {
  description = "Environment variables for CodeBuild project."
  default     = {}
  type        = map(string)
}

variable "cache" {
  default = {
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
    type  = "LOCAL"
  }

  type = object({
    modes = list(string)
    type  = string
  })
}

variable "github" {
  default = {
    branch     = null
    buildspec  = null
    repository = ""
  }

  type = object({
    branch     = string
    buildspec  = string
    repository = string
  })
}

variable "privileged_mode" {
  description = "Enable/disable running the Docker daemon inside a Docker container."
  default     = false
  type        = string
}

variable "project_name" {
  description = "Name of the CodeBuild project."
  type        = string
}

variable "project_description" {
  description = "Description of the CodeBuild project."
  type        = string
}

variable "schedule_name" {
  description = "Name of the EventBridge Scheduler schedule."
  default     = ""
  type        = string
}

variable "schedule_description" {
  description = "Description of the EventBridge Scheduler schedule."
  default     = ""
  type        = string
}

variable "schedule_expression" {
  description = "Cron job expression for the EventBridge Scheduler schedule."
  # At 09:00 AM, only on Tuesday
  default = "cron(0 9 ? * 2 *)"
  type    = string
}

variable "webhook_filters" {
  description = "Webhook filters for the CodeBuild project."
  default = [
    [
      {
        type    = "EVENT"
        pattern = "PUSH"
      }
    ]
  ]
  type = list(list(object({
    type    = string
    pattern = string
  })))
}

variable "attached_policies" {
  description = "Existing policies to attach"
  type        = any
  default     = {}
}

variable "build_timeout" {
  description = "Execution timeout in minutes"
  type        = number
  default     = 60
}

variable "concurrent_build_limit" {
  description = "Maxiumum number of concurrent builds"
  type        = number
  default     = null
}
