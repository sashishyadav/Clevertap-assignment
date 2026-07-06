variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name used as the dynamic CloudFront origin."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM cert ARN (controls origin protocol policy to the ALB)."
  type        = string
}
