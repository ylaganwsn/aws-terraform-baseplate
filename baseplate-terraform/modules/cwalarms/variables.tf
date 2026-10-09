variable "project_name" {}
variable "environment" {}
variable "email_add1" {
    type = string
    default = "devops@appetiser.com.au"
}
variable "https_endpnt" {
    type = string
    default = "https://6negcghjjc.execute-api.ap-southeast-2.amazonaws.com/webhooks/167030788447446"
}

variable "ec2_as_group_name" {}