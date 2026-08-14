variable "server_port" {
  description = "port to be used by the server for HTTP requests"
  type        = number
  default     = 8080
}

variable "cluster_name" {
  description = "The name that will be used for all cluster resources"
  type        = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state"
  type        = string
}

variable "db_remote_state_key" {
  description = "The path for the database's remote state in S3"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type to run"
  type        = string
}

variable "min_num_size" {
  description = "Minimun number of EC2 instances running in the ASG"
  type        = number
}

variable "max_num_size" {
  description = "Maximun number of EC2 instances running in the ASG"
  type        = number
}