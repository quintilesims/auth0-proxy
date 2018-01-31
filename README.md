# Layer0 Auth0 Proxy

Sometimes, you want to put a sensitive web application behind a login wall.
Sometimes, you don't want to write the authentication logic yourself.
In this repository, we provide a proxy application that authenticates through Auth0 and can be easily inserted into any Terraform deployment.

**NOTE: The Auth0 Proxy requires the `layer0-terraform-provider` binary for Layer0 v0.10.4+.**
You can find appropriate downloads at [http://layer0.ims.io/releases/](http://layer0.ims.io/releases/).


# Usage

## An Example

Let's discuss what a possible deployment might look like.

1. A Layer0 environment in which all of the following resources will live.
2. A sensitive application deployed to AWS.
3. A private load balancer that sits in front of the sensitive application.
4. The auth0-proxy application, also deployed to AWS.
5. A public load balancer that sits in front of the auth0-proxy application.

If we hand-wave away the specifics of the sensitive application (the "myapp" service in the coming example), a sample Terraform deployment of this whole system might look like this:

```
# main.tf

provider "layer0" {
  endpoint        = "${var.endpoint}"
  token           = "${var.token}"
  skip_ssl_verify = true
}

resource "layer0_environment" "demo" {
  name = "demo"
}

resource "layer0_load_balancer" "myapp" {
  name        = "myapp"
  environment = "${layer0_environment.demo.id}"
  private     = true

  port {
    host_port      = 80
    container_port = 80
    protocol       = "http"
  }
}

resource "layer0_service" "myapp" {
  name          = "myapp"
  environment   = "${layer0_environment.demo.id}"
  load_balancer = "${layer0_load_balancer.myapp.id}"
  # and any other values that myapp needs
}

# Here's what we do in order to add the auth0-proxy:
module "auth0" {
  source                  = "github.com/quintilesims/auth0-proxy//terraform"
  auth0_domain            = "SOME AUTH0 DOMAIN"
  auth0_client_id         = "AUTH0 CLIENT ID"
  auth0_client_secret     = "AUTH0 CLIENT SECRET"
  auth0_redirect_uri      = "https://${module.auth0.load_balancer_url}"
  layer0_environment_id   = "${layer0_environment.demo.id}"
  proxy_load_balancer_url = "${layer0_load_balancer.myapp.url}"
  ssl_certificate         = "NAME OF AN SSL CERTIFICATE"
}

output "auth0_proxy_load_balancer_url" {
  value = "https://${module.auth0.load_balancer_url}"
}
```

Now, all traffic should access the sensitive application by using the value of the `auth0_proxy_load_balancer_url` output.

## Required Parameters

There are eight paramters that _must_ be supplied to the Auth0 Proxy module.

**Note:**
The Auth0 Proxy requires a configured Auth0 client that is responsible for authenticating users.
Several of the parameters that the Auth0 Proxy module requires come from this client.

- `source` - The location of the terraform files for the Auth0 Proxy module.
This will probably always be `"github.com/quintilesims/auth0-proxy//terraform"`.

- `auth0_domain` - The domain you will use for Auth0 authentication.

- `auth0_client_id` - The ID of the Auth0 client to be used for authentication.

- `auth0_client_secret` - The secret string of the Auth0 client to be used for authentication.

- `auth0_redirect_uri` - The location to which Auth0 should redirect after authentication.
Unless you have a custom domain, this should be the URL of the Auth0 Proxy's load balancer.
(You can get that programmatically: `"https://${module.auth0.load_balancer_url}"`.)
**NOTE: This must contain the protocol, and must match a URL specified in the Auth0 client's allowed callback URLs.**

- `layer0_environment_id` - The ID of the Layer0 environment in which to deploy the Auth0 Proxy module.
This should be the same environment in which the sensitive application is deployed.

- `proxy_load_balancer_url` - The location to which authenticated traffic should be directed.
In other words, the private load balancer that sits in front of the sensitive application.
**NOTE: This must NOT include the protocol (i.e. "http://").**

- `ssl_certificate_name` - The Auth0 Proxy communicates over https, so you must supply an SSL certificate.
While testing, you can use the default certificate that the Layer0 instance creates (`"l0-YOUR_LAYER0_PREFIX_HERE-api"`).
For production services, it's strongly recommended that you create and use a different certificate.


There are a few other variables with default values that can be overridden in the Auth0 module.
You can find them at the top of the [terraform/layer0.tf](terraform/layer0.tf) file.
