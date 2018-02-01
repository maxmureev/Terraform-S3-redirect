variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "region" {}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

variable "main" {
  type = "map"

  default {
    bucket_name = "my-bucket"
    cdn_domain  = "my.cdn.domain"
    rdr_domain  = "my.rdr.domain"
  }
}
