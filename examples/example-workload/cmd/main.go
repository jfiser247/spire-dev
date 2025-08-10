package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/spiffe/go-spiffe/v2/spiffeid"
	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
)

type WorkloadService struct {
	source     *workloadapi.X509Source
	port       string
	serviceName string
}

type HealthResponse struct {
	Status    string    `json:"status"`
	Service   string    `json:"service"`
	SpiffeID  string    `json:"spiffe_id"`
	Timestamp time.Time `json:"timestamp"`
}

type IdentityResponse struct {
	SpiffeID     string    `json:"spiffe_id"`
	SerialNumber string    `json:"serial_number"`
	NotBefore    time.Time `json:"not_before"`
	NotAfter     time.Time `json:"not_after"`
	DNSNames     []string  `json:"dns_names"`
}

type SecureCallResponse struct {
	Message      string    `json:"message"`
	ClientID     string    `json:"client_id"`
	ServerID     string    `json:"server_id"`
	Timestamp    time.Time `json:"timestamp"`
	Authenticated bool     `json:"authenticated"`
}

func NewWorkloadService(port, serviceName string) (*WorkloadService, error) {
	// Create a workload API client
	ctx := context.Background()
	source, err := workloadapi.NewX509Source(ctx)
	if err != nil {
		return nil, fmt.Errorf("unable to create X509Source: %v", err)
	}

	return &WorkloadService{
		source:      source,
		port:        port,
		serviceName: serviceName,
	}, nil
}

func (ws *WorkloadService) Close() {
	if ws.source != nil {
		ws.source.Close()
	}
}

func (ws *WorkloadService) healthHandler(w http.ResponseWriter, r *http.Request) {
	// Get current SVID
	svid, err := ws.source.GetX509SVID()
	if err != nil {
		log.Printf("Error getting SVID: %v", err)
		http.Error(w, "Unable to fetch SVID", http.StatusInternalServerError)
		return
	}

	response := HealthResponse{
		Status:    "healthy",
		Service:   ws.serviceName,
		SpiffeID:  svid.ID.String(),
		Timestamp: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ws *WorkloadService) identityHandler(w http.ResponseWriter, r *http.Request) {
	// Get current SVID
	svid, err := ws.source.GetX509SVID()
	if err != nil {
		log.Printf("Error getting SVID: %v", err)
		http.Error(w, "Unable to fetch SVID", http.StatusInternalServerError)
		return
	}

	cert := svid.Certificates[0]
	
	response := IdentityResponse{
		SpiffeID:     svid.ID.String(),
		SerialNumber: cert.SerialNumber.String(),
		NotBefore:    cert.NotBefore,
		NotAfter:     cert.NotAfter,
		DNSNames:     cert.DNSNames,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ws *WorkloadService) secureCallHandler(w http.ResponseWriter, r *http.Request) {
	// Get current SVID for server identification
	serverSvid, err := ws.source.GetX509SVID()
	if err != nil {
		log.Printf("Error getting server SVID: %v", err)
		http.Error(w, "Unable to fetch server SVID", http.StatusInternalServerError)
		return
	}

	// Extract client certificate from TLS connection
	var clientSpiffeID string
	var authenticated bool

	if r.TLS != nil && len(r.TLS.PeerCertificates) > 0 {
		// Extract SPIFFE ID from client certificate
		clientCert := r.TLS.PeerCertificates[0]
		for _, uri := range clientCert.URIs {
			if id, err := spiffeid.FromURI(uri); err == nil {
				clientSpiffeID = id.String()
				authenticated = true
				break
			}
		}
	}

	if !authenticated {
		clientSpiffeID = "unauthenticated"
	}

	response := SecureCallResponse{
		Message:       "Secure endpoint accessed successfully",
		ClientID:      clientSpiffeID,
		ServerID:      serverSvid.ID.String(),
		Timestamp:     time.Now(),
		Authenticated: authenticated,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ws *WorkloadService) callExternalService(targetURL, targetSpiffeID string) (*SecureCallResponse, error) {
	// Create TLS config for mutual authentication
	tlsConfig := tlsconfig.MTLSClientConfig(ws.source, ws.source, tlsconfig.AuthorizeID(spiffeid.RequireFromString(targetSpiffeID)))
	
	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(targetURL)
	if err != nil {
		return nil, fmt.Errorf("error making secure request: %v", err)
	}
	defer resp.Body.Close()

	var response SecureCallResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("error decoding response: %v", err)
	}

	return &response, nil
}

func (ws *WorkloadService) externalCallHandler(w http.ResponseWriter, r *http.Request) {
	// Example: Call another SPIFFE-enabled service
	targetURL := r.URL.Query().Get("target_url")
	targetSpiffeID := r.URL.Query().Get("target_spiffe_id")

	if targetURL == "" || targetSpiffeID == "" {
		http.Error(w, "target_url and target_spiffe_id parameters are required", http.StatusBadRequest)
		return
	}

	response, err := ws.callExternalService(targetURL, targetSpiffeID)
	if err != nil {
		log.Printf("Error calling external service: %v", err)
		http.Error(w, fmt.Sprintf("Error calling external service: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ws *WorkloadService) setupRoutes() *mux.Router {
	r := mux.NewRouter()
	
	// Health check endpoint (no TLS required)
	r.HandleFunc("/health", ws.healthHandler).Methods("GET")
	
	// Identity information endpoint (no TLS required)
	r.HandleFunc("/identity", ws.identityHandler).Methods("GET")
	
	// Secure endpoint that requires mutual TLS
	r.HandleFunc("/secure", ws.secureCallHandler).Methods("GET")
	
	// Example of calling another SPIFFE service
	r.HandleFunc("/call-external", ws.externalCallHandler).Methods("GET")

	return r
}

func (ws *WorkloadService) startHTTPServer() {
	router := ws.setupRoutes()
	
	server := &http.Server{
		Addr:    ":" + ws.port,
		Handler: router,
	}

	log.Printf("Starting HTTP server on port %s", ws.port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("HTTP server failed: %v", err)
	}
}

func (ws *WorkloadService) startHTTPSServer() {
	router := ws.setupRoutes()
	
	// Create TLS config for server
	tlsConfig := tlsconfig.MTLSServerConfig(ws.source, ws.source, tlsconfig.AuthorizeAny())
	
	server := &http.Server{
		Addr:      ":8443",
		Handler:   router,
		TLSConfig: tlsConfig,
	}

	log.Printf("Starting HTTPS server on port 8443 with mutual TLS")
	if err := server.ListenAndServeTLS("", ""); err != nil && err != http.ErrServerClosed {
		log.Fatalf("HTTPS server failed: %v", err)
	}
}

func (ws *WorkloadService) logIdentityInfo() {
	svid, err := ws.source.GetX509SVID()
	if err != nil {
		log.Printf("Error getting SVID for logging: %v", err)
		return
	}

	log.Printf("Service started with SPIFFE ID: %s", svid.ID.String())
	log.Printf("Certificate valid from %s to %s", 
		svid.Certificates[0].NotBefore.Format(time.RFC3339),
		svid.Certificates[0].NotAfter.Format(time.RFC3339))
	
	if len(svid.Certificates[0].DNSNames) > 0 {
		log.Printf("DNS names: %v", svid.Certificates[0].DNSNames)
	}
}

func main() {
	// Get configuration from environment variables
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	serviceName := os.Getenv("SERVICE_NAME")
	if serviceName == "" {
		serviceName = "example-workload"
	}

	log.Printf("Starting %s service...", serviceName)

	// Create workload service
	ws, err := NewWorkloadService(port, serviceName)
	if err != nil {
		log.Fatalf("Failed to create workload service: %v", err)
	}
	defer ws.Close()

	// Log identity information
	ws.logIdentityInfo()

	// Start HTTP server in a goroutine
	go ws.startHTTPServer()

	// Start HTTPS server with mutual TLS in a goroutine
	go ws.startHTTPSServer()

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	
	log.Printf("%s service is ready", serviceName)
	log.Printf("HTTP endpoints available at: http://localhost:%s", port)
	log.Printf("HTTPS endpoints available at: https://localhost:8443")
	log.Printf("Available endpoints:")
	log.Printf("  GET /health - Service health check")
	log.Printf("  GET /identity - Service identity information")
	log.Printf("  GET /secure - Secure endpoint requiring mutual TLS")
	log.Printf("  GET /call-external?target_url=<url>&target_spiffe_id=<id> - Call external SPIFFE service")

	// Block until we receive a signal
	<-sigChan
	log.Printf("Shutting down %s service...", serviceName)
}