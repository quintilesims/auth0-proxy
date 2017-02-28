# Variables 

variable "layer0_endpoint" {
  description = "The Layer0 API endpoint"
}

variable "layer0_token" {
  description = "The Layer0 API auth token"
}

variable "layer0_environment_id" {
  description = "ID of the Layer0 environment to build the service"
}

variable "proxy_load_balancer_url" {
  description = "URL of the Layer0 load balancer to proxy requests"
}

variable "proxy_load_balancer_port" {
  description = "Port of the Layer0 load balancer to proxy requests"
  default = 80
}

variable "proxy_load_balancer_scheme" {
  description = "Scheme of the Layer0 load balancer to proxy requests"
  default = "http"
}

variable "auth0_domain" {
  description = "Auth0 domain"
}

variable "auth0_client_id" {
  description = "Auth0 connection name"
}

variable "auth0_client_secret" {
  description = "Auth0 client secret"
}

variable "auth0_session_secret" {
  description = "Secret key to encrypt Auth0 sessions"
}

variable "auth0_session_timeout" {
  description = "Timeout for Auth0 sessions"
  default     = "1hr"
}

variable "ssl_certificate" {
  description = "SSL certificate name for the web load balancer"
}

# Resources

provider "layer0" {
  endpoint        = "${var.layer0_endpoint}"
  token           = "${var.layer0_token}"
  skip_ssl_verify = true
}

# todo: make name configurable
resource "layer0_load_balancer" "proxy" {
  name        = "auth0-proxy"
  environment = "${var.layer0_environment_id}"

  port {
    host_port      = 443
    container_port = 80
    protocol       = "https"
    certificate    = "${var.ssl_certificate}"
  }
}

# todo: make name configurable
resource "layer0_service" "proxy" {
  name          = "auth0-proxy"
  environment   = "${var.layer0_environment_id}"
  deploy        = "${layer0_deploy.proxy.id}"
  load_balancer = "${layer0_load_balancer.proxy.id}"
  scale         = 1
}

# todo: make name configurable
resource "layer0_deploy" "proxy" {
  name    = "auth0-proxy"
  content = "${data.template_file.proxy.rendered}"
}

data "template_file" "proxy" {
  template = "${file("${path.module}/Dockerrun.aws.json")}"

  vars {
    proxy_host          = "${var.proxy_load_balancer_url}"
    proxy_port          = "${var.proxy_load_balancer_port}"
    proxy_scheme        = "${var.proxy_load_balancer_scheme}"
    auth0_domain        = "${var.auth0_domain}"
    auth0_client_id     = "${var.auth0_client_id}"
    auth0_client_secret = "${var.auth0_client_secret}"
    auth0_redirect_uri  = "https://${layer0_load_balancer.proxy.url}"
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

