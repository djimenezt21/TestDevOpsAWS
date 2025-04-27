terraform {
  backend "s3" {
    bucket = "djimeneztest21"
    key    = "terraform"
    region = "us-east-1"
  }
}