# Variables 

variable "auth0_domain" {
  description = "Auth0 domain"
}

variable "auth0_client_id" {
  description = "Auth0 connection name"
}

variable "auth0_client_secret" {
  description = "Auth0 client secret"
}

variable "auth0_proxy_deploy_name" {
  description = "Name of the auth0 proxy deploy"
  default     = "auth0-proxy"
}

variable "auth0_proxy_load_balancer_name" {
  description = "Name of the auth0-proxy load balancer"
  default     = "auth0-proxy"
}

variable "auth0_proxy_service_name" {
  description = "Name of the auth0-proxy service"
  default     = "auth0-proxy"
}

variable "auth0_redirect_uri" {
  description = "Auth0 redirect URI (must include protocol, must be in the Auth0 client's allowed callback URLs)"
}

variable "docker_image_tag" {
  description = "The Docker image tag for the quintilesims/auth0-proxy image"
  default     = "latest"
}

variable "layer0_environment_id" {
  description = "ID of the Layer0 environment in which to build the service"
}

variable "proxy_load_balancer_port" {
  description = "Port of the Layer0 load balancer in front of the protected application"
  default     = 80
}

variable "proxy_load_balancer_scheme" {
  description = "Scheme of the Layer0 load balancer in front of the protected application"
  default     = "http"
}

variable "proxy_load_balancer_url" {
  description = "URL of the Layer0 load balancer in front of the protected application (must NOT include protocol)"
}

variable "session_secret" {
  description = "Secret key to encrypt Auth0 sessions"
  default     = "secret potato"
}

variable "session_timeout" {
  description = "Timeout for Auth0 sessions"
  default     = "1h"
}

variable "ssl_certificate_name" {
  description = "SSL certificate name for the web load balancer"
}

# Resources

resource "layer0_load_balancer" "proxy" {
  name        = "${var.auth0_proxy_load_balancer_name}"
  environment = "${var.layer0_environment_id}"

  port {
    host_port      = 443
    container_port = 80
    protocol       = "https"
    certificate    = "${var.ssl_certificate_name}"
  }
}

resource "layer0_service" "proxy" {
  name          = "${var.auth0_proxy_service_name}"
  environment   = "${var.layer0_environment_id}"
  deploy        = "${layer0_deploy.proxy.id}"
  load_balancer = "${layer0_load_balancer.proxy.id}"
  scale         = 1
}

resource "layer0_deploy" "proxy" {
  name    = "${var.auth0_proxy_deploy_name}"
  content = "${data.template_file.proxy.rendered}"
}

data "template_file" "proxy" {
  template = "${file("${path.module}/Dockerrun.aws.json")}"

  vars {
    docker_image_tag    = "${var.docker_image_tag}"
    proxy_host          = "${var.proxy_load_balancer_url}"
    proxy_port          = "${var.proxy_load_balancer_port}"
    proxy_scheme        = "${var.proxy_load_balancer_scheme}"
    auth0_domain        = "${var.auth0_domain}"
    auth0_client_id     = "${var.auth0_client_id}"
    auth0_client_secret = "${var.auth0_client_secret}"
    auth0_redirect_uri  = "${var.auth0_redirect_uri}"
    session_secret      = "${var.session_secret}"
    session_timeout     = "${var.session_timeout}"
  }
}

# Outputs

output "load_balancer_id" {
  value = "${layer0_load_balancer.proxy.id}"
}

output "load_balancer_url" {
  value = "${layer0_load_balancer.proxy.url}"
}

output "service_id" {
  value = "${layer0_service.proxy.id}"
}

output "deploy_id" {
  value = "${layer0_deploy.proxy.id}"
}
