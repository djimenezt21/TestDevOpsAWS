variable "lambda_function_name" {
    type = string 
    default = "testpython"
}

variable "role_name" {
    type = string 
    default = "dbcreate_logging_role"
}

variable "policy_name" {
    type = string 
    default = "dbcreate_logging_policy"
}

variable "api_name" {
    type = string 
    default = "users_api"
}

variable "dynamodb_table_name" {
    type = string 
    default = "user_table"
}