package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png" // Import for PNG support
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	groqAPIURL    = "https://api.groq.com/openai/v1/chat/completions"
	azureImageAPI = "https://image-ai-project.openai.azure.com/openai/deployments/dall-e-3/images/generations?api-version=2024-04-01-preview"
)

type (
	Message struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	}

	GroqRequest struct {
		Model       string    `json:"model"`
		Messages    []Message `json:"messages"`
		Temperature float64   `json:"temperature"`
		MaxTokens   int       `json:"max_tokens"`
		TopP        float64   `json:"top_p"`
		Stream      bool      `json:"stream"`
	}

	ImageGenerationRequest struct {
		Prompt string `json:"prompt" binding:"required"`
		N      int    `json:"n"`
		Size   string `json:"size"`
	}

	ImageGenerationResponse struct {
		Data []struct {
			URL string `json:"url"`
		} `json:"data"`
	}
)

func ChatHandler(c *gin.Context) {
	apiKey := os.Getenv("GROQ_API_KEY")
	if apiKey == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "GROQ_API_KEY environment variable is not set. Please configure your API key to use the chat feature."})
		return
	}

	var userInput struct {
		Content string `json:"content"`
	}
	if err := c.ShouldBindJSON(&userInput); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	requestBody := GroqRequest{
		Model:       "llama3-8b-8192",
		Messages:    []Message{{Role: "user", Content: userInput.Content}},
		Temperature: 0.6,
		MaxTokens:   4096,
		TopP:        0.95,
		Stream:      false,
	}
	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "JSON marshal error: " + err.Error()})
		return
	}

	req, err := http.NewRequest("POST", groqAPIURL, bytes.NewBuffer(jsonData))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "New request error: " + err.Error()})
		return
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Request failed: " + err.Error()})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Read body error: " + err.Error()})
		return
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(body, &parsed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "JSON unmarshal error: " + err.Error()})
		return
	}

	if resp.StatusCode != http.StatusOK {
		c.JSON(resp.StatusCode, gin.H{"error": string(body)})
		return
	}

	choices, ok := parsed["choices"].([]interface{})
	if !ok || len(choices) == 0 {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No choices in response"})
		return
	}

	messageMap, ok := choices[0].(map[string]interface{})["message"].(map[string]interface{})
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid message structure"})
		return
	}

	message, ok := messageMap["content"].(string)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Content not found in message"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"response": message})
}

func ImageHandler(c *gin.Context) {
	apiKey := os.Getenv("GROQ_API_KEY")
	if apiKey == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "GROQ_API_KEY environment variable is not set. Please configure your API key to use the image analysis feature."})
		return
	}

	// Log the content type of the request
	log.Printf("Received request with Content-Type: %s", c.GetHeader("Content-Type"))

	// Get the multipart form
	form, err := c.MultipartForm()
	if err != nil {
		log.Printf("Error getting multipart form: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Invalid form data: %v", err)})
		return
	}

	// Get the files from the form
	files := form.File["image"]
	if len(files) == 0 {
		log.Printf("No image file found in request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "No image file provided"})
		return
	}

	file := files[0]
	log.Printf("Received file: name=%s, size=%d, header=%v", file.Filename, file.Size, file.Header)

	// Open the file
	src, err := file.Open()
	if err != nil {
		log.Printf("Error opening file: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to open image"})
		return
	}
	defer src.Close()

	// Read the file contents
	buf := new(bytes.Buffer)
	if _, err := io.Copy(buf, src); err != nil {
		log.Printf("Error reading file: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read image data"})
		return
	}

	imageData := buf.Bytes()
	contentType := http.DetectContentType(imageData)
	log.Printf("Detected content type: %s", contentType)

	// Validate content type
	if !strings.HasPrefix(contentType, "image/") {
		log.Printf("Invalid content type: %s", contentType)
		c.JSON(http.StatusBadRequest, gin.H{"error": "File must be an image"})
		return
	}

	// Create properly formatted base64 URL
	base64Image := base64.StdEncoding.EncodeToString(imageData)
	imageURL := fmt.Sprintf("data:%s;base64,%s", contentType, base64Image)

	requestJSON := map[string]interface{}{
		"model": "meta-llama/llama-4-scout-17b-16e-instruct",
		"messages": []map[string]interface{}{
			{
				"role": "user",
				"content": []map[string]interface{}{
					{"type": "text", "text": "What's in this image?"},
					{"type": "image_url", "image_url": map[string]string{
						"url": imageURL,
					}},
				},
			},
		},
	}

	jsonData, err := json.Marshal(requestJSON)
	if err != nil {
		log.Printf("Error marshaling JSON: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "JSON marshal error: " + err.Error()})
		return
	}

	req, err := http.NewRequest("POST", groqAPIURL, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("Error creating request: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "New request error: " + err.Error()})
		return
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Error making request to Groq API: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Request failed: " + err.Error()})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Error reading response body: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Read body error: " + err.Error()})
		return
	}

	// Log response status and first 200 characters of body
	log.Printf("Groq API response status: %d", resp.StatusCode)
	if len(body) > 200 {
		log.Printf("Response preview: %s...", body[:200])
	} else {
		log.Printf("Response: %s", body)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(body, &parsed); err != nil {
		log.Printf("Error unmarshaling JSON: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "JSON unmarshal error: " + err.Error()})
		return
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("Groq API error: %s", string(body))
		c.JSON(resp.StatusCode, gin.H{"error": string(body)})
		return
	}

	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

func downloadAndSaveImage(url string, filename string) error {
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("error downloading image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body) // Read body for more detailed error info
		return fmt.Errorf("error downloading image: HTTP status %s, body: %s", resp.Status, string(body))
	}

	img, format, err := image.Decode(resp.Body)
	if err != nil {
		return fmt.Errorf("error decoding image: %w", err)
	}
	log.Println("Image format:", format)

	outFile, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("error creating file: %w", err)
	}
	defer outFile.Close()

	switch strings.ToLower(format) {
	case "jpeg", "jpg":
		err = jpeg.Encode(outFile, img, nil)
	case "png":
		log.Println("PNG encoding is not directly supported, will be saved as JPEG.")
		err = jpeg.Encode(outFile, img, nil)
	default:
		log.Printf("Warning: Image format %s not supported. Saving as JPEG.\n", format)
		err = jpeg.Encode(outFile, img, nil)
	}

	if err != nil {
		return fmt.Errorf("error encoding image: %w", err)
	}

	log.Println("Image saved as", filename)
	return nil
}

func ImageGenerationHandler(c *gin.Context) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Panic in ImageGenerationHandler: %v", r)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error (panic)"})
		}
	}()

	apiKey := os.Getenv("AZURE_OPENAI_API_KEY")
	if apiKey == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AZURE_OPENAI_API_KEY environment variable not set"})
		return
	}

	// Log the received content type and raw body for debugging
	log.Printf("Received Content-Type: %s", c.GetHeader("Content-Type"))
	rawBody, err := io.ReadAll(c.Request.Body)
	if err != nil {
		log.Printf("Error reading request body: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read request body"})
		return
	}
	log.Printf("Received raw body: %s", string(rawBody))

	// Restore the request body for binding
	c.Request.Body = io.NopCloser(bytes.NewBuffer(rawBody))

	var requestBody ImageGenerationRequest
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		log.Printf("JSON binding error: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON input: " + err.Error()})
		return
	}

	if requestBody.Prompt == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Prompt is required"})
		return
	}

	requestBody.N = 1 // Force single image generation
	if requestBody.Size == "" {
		requestBody.Size = "1024x1024" // Default image size
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "JSON marshal error: " + err.Error()})
		return
	}

	req, err := http.NewRequest("POST", azureImageAPI, bytes.NewBuffer(jsonData))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "New request error: " + err.Error()})
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Request failed: " + err.Error()})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Read body error: " + err.Error()})
		return
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("Azure OpenAI API error: Status %s, Body: %s", resp.Status, string(body))
		var errorResponse struct {
			Error struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.Unmarshal(body, &errorResponse); err == nil && errorResponse.Error.Message != "" {
			c.JSON(resp.StatusCode, gin.H{"error": "Image generation failed: " + errorResponse.Error.Message})
		} else {
			c.JSON(resp.StatusCode, gin.H{"error": "Image generation failed: " + string(body)})
		}
		return
	}

	var responseBody ImageGenerationResponse
	if err := json.Unmarshal(body, &responseBody); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "JSON unmarshal error: " + err.Error()})
		return
	}

	if len(responseBody.Data) == 0 {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No image URL returned"})
		return
	}

	imageURL := responseBody.Data[0].URL
	log.Printf("Image URL: %s", imageURL)

	// Return the image URL in JSON response
	c.JSON(http.StatusOK, gin.H{
		"url": imageURL,
		"status": "success",
	})
}

func loadEnv() {
	// Read .env file
	file, err := os.ReadFile(".env")
	if err != nil {
		log.Printf("Warning: .env file not found: %v", err)
		return
	}

	// Parse each line
	lines := strings.Split(string(file), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.Trim(strings.TrimSpace(parts[1]), `"'`)
		os.Setenv(key, value)
	}
}

func main() {
	// Load environment variables from .env file
	loadEnv()

	router := gin.Default()

	// Serve the main page
	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": "LumaBot API is running",
			"version": "1.0.0",
			"endpoints": []string{
				"/chat - Chat with AI",
				"/image - Image analysis",
				"/image-generator - Generate images",
			},
		})
	})

	// API endpoints
	router.POST("/chat", ChatHandler)
	router.POST("/image", ImageHandler)
	router.POST("/image-generator", ImageGenerationHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Gin run error: %v", err)
	}
}
