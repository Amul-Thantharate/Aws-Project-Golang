# 🤖 LumaBot - AI-Powered Chat & Image Platform

[![Go](https://img.shields.io/badge/Go-1.24+-00ADD8?style=flat&logo=go)](https://go.dev/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Streamlit](https://img.shields.io/badge/Streamlit-1.31+-FF4B4B?style=flat&logo=streamlit&logoColor=white)](https://streamlit.io/)
[![Groq](https://img.shields.io/badge/Groq-API-00B4D8?style=flat)](https://console.groq.com)
[![Azure](https://img.shields.io/badge/Azure_OpenAI-DALL--E-0078D4?style=flat&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![License](https://img.shields.io/badge/License-Apache-blue.svg)](LICENSE)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/Amul-Thantharate/LumaBot/graphs/commit-activity)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)
[![GitHub stars](https://img.shields.io/github/stars/Amul-Thantharate/LumaBot?style=social)](https://github.com/Amul-Thantharate/LumaBot/stargazers)
[![Follow](https://img.shields.io/github/followers/Amul-Thantharate?style=social)](https://github.com/Amul-Thantharate)

LumaBot is a cutting-edge AI platform that seamlessly integrates multiple AI capabilities into one powerful application. It leverages Groq's ultra-fast LLM for intelligent conversations and precise image analysis, while harnessing Azure OpenAI's DALL-E for stunning image generation. With an intuitive Streamlit interface, it offers real-time chat interactions, detailed image analysis, and creative image generation - all while maintaining a complete history of your AI interactions.

## ✨ Features

- 💬 **AI Chat**: Engage in conversations with advanced AI
- 🔍 **Image Analysis**: Get detailed descriptions of uploaded images
- 🎨 **Image Generation**: Create custom images from text descriptions
- 📝 **History Management**: Track chat, analysis, and generated images
- 🌐 **Web Interface**: Clean and intuitive Streamlit UI

## 🚀 Getting Started

### Prerequisites

- Go 1.24 or later
- Python 3.11 or later
- pip (Python package manager)

### 🔑 API Keys Required

1. **Groq API Key** (for Chat & Image Analysis)
   - Sign up at [Groq Cloud Console](https://console.groq.com)
   - Create a new API key
   - Copy the key (starts with "gsk_")

2. **Azure OpenAI API Key** (for Image Generation)
   - Sign up for [Azure OpenAI Service](https://portal.azure.com)
   - Create a new resource
   - Get your API key from the resource settings

### 🛠️ Installation

You can run LumaBot either directly or using Docker.

#### Option 1: Direct Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Amul-Thantharate/LumaBot.git
   cd LumaBot
   ```

#### Option 2: Docker Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Amul-Thantharate/LumaBot.git
   cd LumaBot
   ```

2. Build and run with Docker:
   ```bash
   docker build -t lumabot .
   docker run -p 8080:8080 -p 8501:8501 lumabot
   ```

   The application will be available at:
   - Go backend: http://localhost:8080
   - Streamlit UI: http://localhost:8501

2. Create and activate a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### ⚙️ Configuration

1. Create a `.env` file in the project root:
   ```bash
   touch .env
   ```

2. Add your API keys to the `.env` file:
   ```env
   GROQ_API_KEY="your_groq_api_key_here"
   AZURE_OPENAI_API_KEY="your_azure_api_key_here"
   ```

## 🚀 Running the Application

### Method 1: With Streamlit UI (Recommended)

1. Start the Go server:
   ```bash
   go run main.go
   ```

2. In a new terminal, start the Streamlit app:
   ```bash
   streamlit run main.py
   ```

3. Open your browser and visit:
   - Local: http://localhost:8501
   - Network: http://localhost:8501

### Method 2: Without Streamlit (API Only)

1. Start the Go server:
   ```bash
   go run main.go
   ```

2. Use the following API endpoints:
   - Chat: `POST http://localhost:8080/chat`
   - Image Analysis: `POST http://localhost:8080/image`
   - Image Generation: `POST http://localhost:8080/image-generator`

Example API calls:
```bash
# Chat
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, how are you?"}'

# Image Analysis
curl -X POST http://localhost:8080/image \
  -F "image=@path/to/your/image.jpg"

# Image Generation
curl -X POST http://localhost:8080/image-generator \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A sunset over mountains", "size": "1024x1024"}'
```

## 📱 Features Overview

### Chat Tab
- Real-time AI conversations
- Chat history with timestamp
- Clear chat history option

### Image Analysis Tab
- Upload images (JPG, JPEG, PNG)
- Get detailed AI analysis
- View analysis history
- Clear analysis history option

### Image Generation Tab
- Create custom images from text
- Choose image size
- View generation history with download links
- Clear generation history option

## 🤝 Contributing

Feel free to contribute to this project. Open issues or submit pull requests on GitHub.

## 👨‍💻 Author

- 🚀 **Amul Thantharate**
  - LinkedIn: [Amul Thantharate](https://www.linkedin.com/in/amul-thantharate)
  - GitHub: [amul-thantharate](https://github.com/amul-thantharate)

## 📄 License

This project is licensed under the Apache License - see the [LICENSE](LICENSE) file for details.
