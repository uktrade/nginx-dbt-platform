locals {
  attached_policies = toset([
    "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicPowerUser",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ])
}
