variable "ami-id" {
  default = ""
}

variable "instance-type" {
  default = "t2.micro"
}

variable "ebs-size" {
  default = 10
}

variable "ebs-type" {
  default = "gp2"
}

variable "ebs-snapshot-schedule" {
  default = "cron(0 9 ? * MON *)"
}

variable "ebs-snapshot-retention-days" {
  default = 30
}
