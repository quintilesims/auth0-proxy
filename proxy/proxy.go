package proxy

import (
	"fmt"
	"github.com/quintilesims/auth0-proxy/authenticator"
	"net/http"
	"net/http/httputil"
	"net/url"
)

type Proxy struct {
	Authenticator authenticator.Authenticator
	reverseProxy  *httputil.ReverseProxy
}

func New(a authenticator.Authenticator, host string, port int) *Proxy {
	return &Proxy{
		Authenticator: a,
		reverseProxy: httputil.NewSingleHostReverseProxy(&url.URL{
			Host:   fmt.Sprintf("%s:%d", host, port),
			Scheme: "http",
		}),
	}
}

func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	serveProxy, err := p.Authenticator.Authenticate(w, r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if !serveProxy {
		return
	}

	p.reverseProxy.ServeHTTP(w, r)
}
