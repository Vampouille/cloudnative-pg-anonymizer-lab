terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
      version = "~> 2.73"
    }
		pass = {
			source = "mecodia/pass"
			version = "~> 3.1"
		}
  }
  required_version = "~> 1.11"
}
