package main

import (
	"fmt"
	"github.com/gorilla/context"
	"github.com/quintilesims/auth0-proxy/authenticator"
	"github.com/quintilesims/auth0-proxy/proxy"
	"github.com/urfave/cli"
	"log"
	"net/http"
	"os"
	"time"
)

var Version string

func main() {
	if Version == "" {
		Version = "unset/developer"
	}

	app := cli.NewApp()
	app.Name = "Auth0 Proxy"
	app.Version = Version
	app.Flags = []cli.Flag{
		cli.IntFlag{
			Name:   "p, port",
			Value:  80,
			EnvVar: "AP_PORT",
		},
		cli.StringFlag{
			Name:   "proxy-host",
			EnvVar: "AP_PROXY_URL",
		},
		cli.IntFlag{
			Name:   "proxy-port",
			Value:  80,
			EnvVar: "AP_PROXY_PORT",
		},
		cli.StringFlag{
			Name:   "auth0-domain",
			EnvVar: "AP_AUTH0_DOMAIN",
		},
		cli.StringFlag{
			Name:   "auth0-client-id",
			EnvVar: "AP_AUTH0_CLIENT_ID",
		},
		cli.StringFlag{
			Name:   "auth0-client-secret",
			EnvVar: "AP_AUTH0_CLIENT_SECRET",
		},
		cli.StringFlag{
			Name:   "auth0-redirect-uri",
			EnvVar: "AP_AUTH0_REDIRECT_URI",
		},
	}

	app.Action = func(c *cli.Context) error {
		authenticator := authenticator.NewAuth0Authenticator(
			c.String("auth0-domain"),
			c.String("auth0-client-id"),
			c.String("auth0-client-secret"),
			c.String("auth0-redirect-uri"),
			time.Second*10)

		proxy := proxy.New(authenticator, c.String("proxy-host"), c.Int("proxy-port"))

		addr := fmt.Sprintf(":%d", c.Int("port"))
		log.Printf("Listending on %s\n", addr)
		return http.ListenAndServe(addr, context.ClearHandler(proxy))
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
