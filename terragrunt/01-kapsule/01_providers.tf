data "pass_password" "scaleway" {
  path = "terraform/scaleway/gs-pf-fr-prod"
}

provider "scaleway" {
  zone   = local.variables.zone
  region = local.variables.region

  access_key = data.pass_password.scaleway.data["SCW_ACCESS_KEY"]
  secret_key = data.pass_password.scaleway.data["SCW_SECRET_KEY"]
  project_id = local.variables.scaleway_project_id
  organization_id = data.pass_password.scaleway.data["SCW_DEFAULT_ORGANIZATION_ID"]

}
