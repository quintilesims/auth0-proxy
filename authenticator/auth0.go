package authenticator

import (
	"bytes"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"github.com/gorilla/sessions"
	"net/http"
	"net/url"
	"time"
)

// todo: move this
var secret = []byte("something-very-secret")

type Auth0Proxy struct {
	Proxy          *httputil.ReverseProxy
	Domain         string
	ClientID       string
	ClientSecret   string
	RedirectURI    string
	SessionTimeout time.Duration
	store          *sessions.CookieStore
	requests       map[string]*http.Request
}

func NewAuth0Proxy(p *httputil.ReverseProxy, domain, clientID, clientSecret, redirectURI string, sessionTimeout time.Duration) *Auth0Proxy {
	return &Auth0Proxy{
		Proxy:          p,
		Domain:         domain,
		ClientID:       clientID,
		ClientSecret:   clientSecret,
		RedirectURI:    redirectURI,
		SessionTimeout: sessionTimeout,
		store:          sessions.NewCookieStore(secret),
		requests:       map[string]*http.Request{},
	}
}

func (a *Auth0Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	session, err := a.store.Get(r, "auth0-proxy")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if !session.IsNew {
		a.Proxy.ServeHTTP(w, r)
		return
	}

	if code := r.URL.Query().Get("code"); code != "" {
		a.handleAuth0Callback(w, r, code)
		return
	}

	a.handleAuth0Redirect(w, r)
}

func (a *Auth0Proxy) handleAuth0Redirect(w http.ResponseWriter, r *http.Request) {
	key := generateKey()
	a.requests[key] = r

	url := url.URL{
		Scheme:   "https",
		Host:     a.Domain,
		Path:     "/authorize",
		RawQuery: fmt.Sprintf("response_type=code&client_id=%s&redirect_uri=%s&state=%s", a.ClientID, a.RedirectURI, key),
	}

	http.Redirect(w, r, url.String(), http.StatusSeeOther)
}

func (a *Auth0Proxy) handleAuth0Callback(w http.ResponseWriter, r *http.Request, code string) {
	if err := a.validateCode(code); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	session, err := a.store.Get(r, "auth0-proxy")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	session.Options.MaxAge = int(a.SessionTimeout.Seconds())
	session.Save(r, w)

	key := r.URL.Query().Get("state")
	if originalRequest := a.requests[key]; originalRequest != nil {
		fmt.Println("requst hit!")
		delete(a.requests, key)
		a.Proxy.ServeHTTP(w, originalRequest)
		return
	}

	a.Proxy.ServeHTTP(w, r)
}

type CodeExchangeRequest struct {
	GrantType    string `json:"grant_type"`
	ClientID     string `json:"client_id"`
	ClientSecret string `json:'client_secret"`
	Code         string `json:"code"`
	RedirectURI  string `json:"redirect_uri"`
}

func (a *Auth0Proxy) validateCode(code string) error {
	cer := CodeExchangeRequest{
		GrantType:    "authorization_code",
		ClientID:     a.ClientID,
		ClientSecret: a.ClientSecret,
		Code:         code,
		RedirectURI:  a.RedirectURI,
	}

	b, err := json.Marshal(cer)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("https://%s/oauth/token", a.Domain)
	req, err := http.NewRequest("POST", url, bytes.NewReader(b))
	if err != nil {
		return err
	}

	req.Header.Add("content-type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("Invalid status code")
	}

	return nil
}

func generateKey() string {
	salt := time.Now().Format(time.StampNano)
	return fmt.Sprintf("%x", md5.Sum([]byte(salt)))
}
