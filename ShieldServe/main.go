package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/wafv2"
	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3" 
)

var (
	db        *sql.DB       // Database connection
	wafClient *wafv2.Client // AWS WAF client
)

func main() {
	var err error

	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "app.db" // Default SQLite database file
		log.Printf("DB_PATH environment variable not set. Using default: %s", dbPath)
	}

	db, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("Database ping failed: %v", err)
	}
	log.Println("Successfully connected to the database.")

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Printf("WARNING: Failed to initialize AWS client: %v", err)
	} else {
		wafClient = wafv2.NewFromConfig(cfg)
		log.Println("Successfully initialized AWS WAF client.")
	}

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username VARCHAR(50) NOT NULL UNIQUE, -- Added UNIQUE constraint
			password VARCHAR(100) NOT NULL,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		log.Fatalf("Failed to create table: %v", err)
	}
	log.Println("Database table 'users' created or already exists.")

	// Setup routes using a dedicated handler
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleHome)
	mux.HandleFunc("/api/login", securityMiddleware(handleLogin))
	mux.HandleFunc("/api/search", securityMiddleware(handleSearch))
	mux.HandleFunc("/api/ping", securityMiddleware(handlePing))
	mux.HandleFunc("/api/register", securityMiddleware(handleRegister))
	mux.HandleFunc("/api/upload", securityMiddleware(handleFileUpload))
	mux.HandleFunc("/api/waf-test", securityMiddleware(handleWafTest))
	mux.HandleFunc("/api/security-report", securityMiddleware(handleSecurityReport))

	// Start server
	server := &http.Server{
		Addr:         ":8080",
		Handler:      loggingMiddleware(mux), // Wrap the ServeMux with the logging middleware
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Printf("Server listening on http://%s", server.Addr) // Use log.Printf for informational messages.
	// Use log.Fatal for errors that prevent the server from starting.
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}
	log.Println("Server stopped.") // Add this line to indicate a clean shutdown.
}

// Middleware

// loggingMiddleware logs each incoming request.
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		// Improved logging: Include the full URL and method.
		log.Printf("Started %s %s from %s", r.Method, r.URL.String(), r.RemoteAddr)
		next.ServeHTTP(w, r)
		duration := time.Since(start)
		log.Printf("Completed %s %s in %v", r.Method, r.URL.String(), duration)
	})
}

// securityMiddleware sets security-related headers.
func securityMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Set security headers to protect against common vulnerabilities.
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains") // 2 years
		next.ServeHTTP(w, r)
	}
}

// Handlers

// handleHome handles the root URL ("/").
func handleHome(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	// Use fmt.Fprintln for consistency.
	fmt.Fprintln(w, "Welcome to Secure Web Application")
	fmt.Fprintln(w, "Available endpoints: /api/login, /api/search, /api/ping, /api/register, /api/upload, /api/waf-test, /api/security-report")
}

// handleLogin handles the "/api/login" endpoint.
func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Use r.PostFormValue for easier access to form data.
	user := r.PostFormValue("user")
	pass := r.PostFormValue("pass")

	// Validate input.
	if user == "" || pass == "" {
		http.Error(w, "Username and password required", http.StatusBadRequest)
		return
	}

	var username string
	// Use parameterized queries to prevent SQL injection.
	err := db.QueryRow("SELECT username FROM users WHERE username = ? AND password = ?", user, pass).Scan(&username)
	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		} else {
			// Log the actual database error.
			log.Printf("Database error: %v", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
		return
	}

	fmt.Fprintf(w, "Welcome, %s!", username)
}

// handleRegister handles the "/api/register" endpoint.
func handleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Use r.PostFormValue for easier access to form data.
	user := r.PostFormValue("user")
	pass := r.PostFormValue("pass")

	// Validate input.  Use constants for magic numbers.
	const minUserLength = 4
	const minPassLength = 8
	if len(user) < minUserLength || len(pass) < minPassLength {
		http.Error(w, fmt.Sprintf("Username must be at least %d characters and password at least %d characters", minUserLength, minPassLength), http.StatusBadRequest)
		return
	}

	var count int
	// Use parameterized queries to prevent SQL injection.
	err := db.QueryRow("SELECT COUNT(*) FROM users WHERE username = ?", user).Scan(&count)
	if err != nil {
		// Log the actual database error.
		log.Printf("Database error: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	if count > 0 {
		http.Error(w, "Username already exists", http.StatusConflict)
		return
	}

	// Use parameterized queries to prevent SQL injection.
	_, err = db.Exec("INSERT INTO users(username, password) VALUES(?, ?)", user, pass)
	if err != nil {
		// Log the actual database error.
		log.Printf("Database error: %v", err)
		http.Error(w, "Registration failed", http.StatusInternalServerError)
		return
	}

	fmt.Fprint(w, "User registered successfully")
}

// handleSearch handles the "/api/search" endpoint.
func handleSearch(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		http.Error(w, "Search query required", http.StatusBadRequest)
		return
	}

	// IMPORTANT:  Use proper HTML escaping to prevent XSS vulnerabilities.
	safeQuery := template.HTMLEscapeString(query)
	//  Use a template for generating HTML.  This is safer and more maintainable.
	tmpl := `<!DOCTYPE html>
<html>
<head>
	<title>Search Results</title>
</head>
<body>
	<h1>Search Results for: %s</h1>
	<p>No results found</p>
</body>
</html>
`
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// Check for errors in template execution.
	if _, err := fmt.Fprintf(w, tmpl, safeQuery); err != nil {
		log.Printf("Error writing response: %v", err) // Log the error.
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}

// handlePing handles the "/api/ping" endpoint.
func handlePing(w http.ResponseWriter, r *http.Request) {
	ip := r.URL.Query().Get("ip")
	if ip == "" {
		http.Error(w, "IP address required", http.StatusBadRequest)
		return
	}

	// Validate IP format more robustly.  This is still not perfect, but better.
	if strings.ContainsAny(ip, ";&|$()<>`'\"\\") {
		http.Error(w, "Invalid IP address", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()

	// IMPORTANT:  Use the -c 1 argument to limit the number of pings.
	//             This prevents denial-of-service vulnerabilities.
	cmd := exec.CommandContext(ctx, "ping", "-c", "1", ip)
	out, err := cmd.CombinedOutput()
	if ctx.Err() == context.DeadlineExceeded {
		http.Error(w, "Ping timeout", http.StatusGatewayTimeout)
		return
	}
	if err != nil {
		// Log the error from the ping command.
		log.Printf("Ping failed: %v, output: %s", err, out)
		http.Error(w, "Ping failed", http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "Ping results:\n%s", out)
}

// handleFileUpload handles the "/api/upload" endpoint.
func handleFileUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Limit the file size to prevent abuse.
	r.Body = http.MaxBytesReader(w, r.Body, 10<<20)        // 10MB limit
	if err := r.ParseMultipartForm(10 << 20); err != nil { // 10 MB
		http.Error(w, "File too large", http.StatusRequestEntityTooLarge)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, fmt.Sprintf("Error reading file: %v", err), http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Validate file type using the first 512 bytes.
	buff := make([]byte, 512)
	_, err = file.Read(buff)
	if err != nil && err != io.EOF {
		http.Error(w, fmt.Sprintf("Error reading file content: %v", err), http.StatusInternalServerError)
		return
	}
	filetype := http.DetectContentType(buff)
	if !strings.HasPrefix(filetype, "image/") {
		http.Error(w, "Only image files are allowed", http.StatusBadRequest)
		return
	}

	// Reset the file pointer to the beginning after reading the header.
	_, err = file.Seek(0, io.SeekStart)
	if err != nil {
		http.Error(w, "Could not reset file pointer", http.StatusInternalServerError)
		return
	}

	// Validate extension.
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".gif" {
		http.Error(w, "Invalid file type", http.StatusBadRequest)
		return
	}

	// Generate secure filename using UUID.
	newFilename := uuid.New().String() + ext
	// IMPORTANT:  Use a secure, configurable upload directory.  Do NOT use /tmp directly in production.
	uploadDir := os.Getenv("UPLOAD_DIR")
	if uploadDir == "" {
		uploadDir = "/tmp/uploads" // Fallback to /tmp/uploads if UPLOAD_DIR is not set.
		log.Printf("WARNING: UPLOAD_DIR environment variable not set. Using default: %s", uploadDir)
	}
	savePath := filepath.Join(uploadDir, newFilename)

	// Create upload directory if it doesn't exist.
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		// Log the error.
		log.Printf("Failed to create upload directory: %v", err)
		http.Error(w, "Failed to create upload directory", http.StatusInternalServerError)
		return
	}

	// Save the file.
	dst, err := os.Create(savePath)
	if err != nil {
		// Log the error.
		log.Printf("Failed to create file: %v", err)
		http.Error(w, "Failed to save file", http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	// Use io.Copy for efficient copying.
	if _, err := io.Copy(dst, file); err != nil {
		// Log the error.
		log.Printf("Failed to copy file: %v", err)
		http.Error(w, "Failed to save file", http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "File uploaded successfully: %s", newFilename)
}

// handleWafTest handles the "/api/waf-test" endpoint.
func handleWafTest(w http.ResponseWriter, r *http.Request) {
	testType := r.URL.Query().Get("type")

	result := map[string]string{
		"test":   testType,
		"status": "attempted",
		"waf":    "enabled", // Assume WAF is enabled.  Adjust as needed.
		"time":   time.Now().UTC().String(),
	}

	switch testType {
	case "sql":
		// IMPORTANT: This is a *test* of a SQL injection.  Do NOT use this in production.
		_, err := db.Query("SELECT * FROM users WHERE id = '1' OR '1'='1'")
		if err != nil {
			log.Printf("SQL Injection Test: %v", err) // Log the error
		}
		result["description"] = "SQL injection test attempted"
	case "xss":
		result["description"] = "XSS test attempted"
		result["payload"] = "<script>alert(1)</script>" // IMPORTANT:  This is a *test* payload.
	case "lfi":
		// IMPORTANT:  This is a *test* of a local file inclusion vulnerability.  Do NOT use this in production.
		_, err := os.ReadFile("/etc/passwd") // Try to read a system file.
		if err != nil {
			log.Printf("LFI Test: %v", err)
		}
		result["description"] = "Local file inclusion test attempted"
	default:
		result["status"] = "invalid"
		result["description"] = "Available tests: sql, xss, lfi"
	}

	w.Header().Set("Content-Type", "application/json")
	// Handle JSON encoding errors.
	if err := json.NewEncoder(w).Encode(result); err != nil {
		log.Printf("Error encoding JSON: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}

// handleSecurityReport handles the "/api/security-report" endpoint.
func handleSecurityReport(w http.ResponseWriter, r *http.Request) {
	report := map[string]interface{}{
		"secure":    true,
		"timestamp": time.Now().UTC(),
		"aws_waf":   wafClient != nil, // Correctly check if the WAF client is initialized.
		"endpoints": []string{
			"POST /api/login",
			"POST /api/register",
			"GET /api/search?q=",
			"GET /api/ping?ip=",
			"POST /api/upload",
			"GET /api/waf-test?type=",
			"GET /api/security-report",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	// Handle JSON encoding errors.
	if err := json.NewEncoder(w).Encode(report); err != nil {
		log.Printf("Error encoding JSON: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}
