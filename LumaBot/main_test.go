package main

import (
	"bytes"
	"encoding/json"
	"image"
	"image/jpeg"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
)

// TestChatHandler tests the ChatHandler function
func TestChatHandler(t *testing.T) {
	// Set up test environment
	os.Setenv("GROQ_API_KEY", "test-api-key")
	defer os.Unsetenv("GROQ_API_KEY")

	// Initialize Gin router
	r := gin.Default()
	r.POST("/chat", ChatHandler)

	// Test case 1: Valid request
	validInput := map[string]string{"content": "Hello, how are you?"}
	validJSON, _ := json.Marshal(validInput)
	req1 := httptest.NewRequest(http.MethodPost, "/chat", bytes.NewBuffer(validJSON))
	req1.Header.Set("Content-Type", "application/json")
	rec1 := httptest.NewRecorder()
	r.ServeHTTP(rec1, req1)

	if rec1.Code != http.StatusUnauthorized {
		t.Errorf("Expected status %d, got %d", http.StatusUnauthorized, rec1.Code)
	}

	// Test case 2: Missing API key
	os.Unsetenv("GROQ_API_KEY")
	req2 := httptest.NewRequest(http.MethodPost, "/chat", bytes.NewBuffer(validJSON))
	req2.Header.Set("Content-Type", "application/json")
	rec2 := httptest.NewRecorder()
	r.ServeHTTP(rec2, req2)

	if rec2.Code != http.StatusUnauthorized {
		t.Errorf("Expected status %d, got %d", http.StatusUnauthorized, rec2.Code)
	}

	// Test case 3: Invalid input
	invalidInput := map[string]string{"invalid": "data"}
	invalidJSON, _ := json.Marshal(invalidInput)
	req3 := httptest.NewRequest(http.MethodPost, "/chat", bytes.NewBuffer(invalidJSON))
	req3.Header.Set("Content-Type", "application/json")
	rec3 := httptest.NewRecorder()
	r.ServeHTTP(rec3, req3)

	if rec3.Code != http.StatusUnauthorized {
		t.Errorf("Expected status %d, got %d", http.StatusUnauthorized, rec3.Code)
	}
}

// TestImageGenerationHandler tests the ImageGenerationHandler function
func TestImageGenerationHandler(t *testing.T) {
	// Set up test environment
	os.Setenv("AZURE_IMAGE_API_KEY", "test-api-key")
	defer os.Unsetenv("AZURE_IMAGE_API_KEY")

	// Initialize Gin router
	r := gin.Default()
	r.POST("/image/generate", ImageGenerationHandler)

	// Test case 1: Valid request
	validInput := map[string]interface{}{
		"prompt": "A beautiful sunset",
		"n":      1,
		"size":   "1024x1024",
	}
	validJSON, _ := json.Marshal(validInput)
	req1 := httptest.NewRequest(http.MethodPost, "/image/generate", bytes.NewBuffer(validJSON))
	req1.Header.Set("Content-Type", "application/json")
	rec1 := httptest.NewRecorder()
	r.ServeHTTP(rec1, req1)

	if rec1.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, rec1.Code)
	}

	// Test case 2: Missing API key
	os.Unsetenv("AZURE_IMAGE_API_KEY")
	req2 := httptest.NewRequest(http.MethodPost, "/image/generate", bytes.NewBuffer(validJSON))
	req2.Header.Set("Content-Type", "application/json")
	rec2 := httptest.NewRecorder()
	r.ServeHTTP(rec2, req2)

	if rec2.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, rec2.Code)
	}

	// Test case 3: Invalid input
	invalidInput := map[string]interface{}{
		"prompt": "",
	}
	invalidJSON, _ := json.Marshal(invalidInput)
	req3 := httptest.NewRequest(http.MethodPost, "/image/generate", bytes.NewBuffer(invalidJSON))
	req3.Header.Set("Content-Type", "application/json")
	rec3 := httptest.NewRecorder()
	r.ServeHTTP(rec3, req3)

	if rec3.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, rec3.Code)
	}
}

// TestDownloadAndSaveImage tests the downloadAndSaveImage function
func TestDownloadAndSaveImage(t *testing.T) {
	// Test case 1: Valid URL
	testURL := "https://example.com/test.jpg"
	testFilename := "test.jpg"

	// Mock the HTTP request with a valid image
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Create a small test image
		img := image.NewRGBA(image.Rect(0, 0, 1, 1))
		buf := new(bytes.Buffer)
		jpeg.Encode(buf, img, &jpeg.Options{Quality: 100})
		w.Write(buf.Bytes())
	}))
	defer mockServer.Close()
	
	// Replace the test URL with the mock server URL
	testURL = mockServer.URL
	
	// Test the function
	err := downloadAndSaveImage(testURL, testFilename)
	if err != nil {
		t.Errorf("Expected no error, got: %v", err)
	}

	// Clean up
	os.Remove(testFilename)
}
