import streamlit as st
import requests
import json
import base64
from PIL import Image
import io
import time
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Log environment variables (without showing the actual values)
st.set_page_config(page_title="LumaBot Dashboard")


# Configuration
API_BASE_URL = "http://127.0.0.1:8080"  # Internal container address for Go service
st.title("AI Services Dashboard")

# Check for API keys in environment
GROQ_API_KEY = os.getenv('GROQ_API_KEY')
AZURE_OPENAI_KEY = os.getenv('AZURE_OPENAI_API_KEY')

# Display API key status in sidebar
with st.sidebar:
    st.header("API Key Status")
    if not GROQ_API_KEY:
        st.error("⚠️ GROQ API Key not set")
        st.info("Chat and Image Analysis features will not work without a GROQ API key")
    else:
        st.success("✅ GROQ API Key configured")
        
    if not AZURE_OPENAI_KEY:
        st.error("⚠️ Azure OpenAI API Key not set")
        st.info("Image Generation feature will not work without an Azure OpenAI API key")
    else:
        st.success("✅ Azure OpenAI API Key configured")

# Helper function for API requests
def make_request(method, endpoint, data=None, files=None):
    url = f"{API_BASE_URL}{endpoint}"
    try:
        if method == "GET":
            response = requests.get(url)
        elif method == "POST":
            if files:
                response = requests.post(url, files=files)
            else:
                response = requests.post(url, json=data)
                
        if response.status_code == 401:
            if endpoint == "/chat" or endpoint == "/image":
                return {"error": "GROQ API Key not configured. Please set the GROQ_API_KEY environment variable."}
            elif endpoint == "/image-generator":
                return {"error": "Azure OpenAI API Key not configured. Please set the AZURE_OPENAI_API_KEY environment variable."}
        
        response.raise_for_status()
        return response.json() if response.content else {"status": "success"}
    except requests.exceptions.RequestException as e:
        error_msg = str(e)
        if "Connection refused" in error_msg:
            return {"error": "Could not connect to the API server. Please make sure the Go server is running."}
        return {"error": error_msg}

# Create tabs for different operations
tab1, tab2, tab3 = st.tabs(["Chat", "Image Analysis", "Image Generation"])

# Initialize session state for chat history, image history, and image analysis history
if 'chat_history' not in st.session_state:
    st.session_state.chat_history = []

if 'image_history' not in st.session_state:
    st.session_state.image_history = []
    
if 'analysis_history' not in st.session_state:
    st.session_state.analysis_history = []

with tab1:
    # POST /chat - Chat with AI
    st.header("Chat with AI")
    
    # Display chat history
    for chat in st.session_state.chat_history:
        with st.container():
            st.markdown(f"**You:** {chat['message']}")
            if 'error' in chat['response']:
                st.error(chat['response']['error'])
            else:
                st.markdown(f"**AI:** {chat['response'].get('response', 'No response')}")
            st.markdown("---")
    
    with st.form("chat_form"):
        message = st.text_area("Your message", height=150)
        submitted = st.form_submit_button("Send")
        if submitted:
            if message.strip():
                with st.spinner("Waiting for response..."):
                    result = make_request("POST", "/chat", data={"content": message})
                    # Add to chat history
                    st.session_state.chat_history.append({
                        'message': message,
                        'response': result,
                        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
                    })
                    
                    if "error" in result:
                        st.error(result["error"])
                    else:
                        st.success("Received response!")
                        st.write(result.get("response", "No response content"))
            else:
                st.warning("Please enter a message")
    
    # Clear chat history button
    if st.session_state.chat_history:
        if st.button("Clear Chat History"):
            st.session_state.chat_history = []
            st.rerun()

with tab2:
    # POST /image - Analyze image
    st.header("Image Analysis")
    uploaded_file = st.file_uploader("Upload an image", type=["jpg", "jpeg", "png"])
    
    # Show analysis history and clear button
    if st.session_state.analysis_history:
        if st.button("Clear Analysis History", key="clear_analysis"):
            st.session_state.analysis_history = []
            st.rerun()
        
        st.subheader("Analysis History")
        for idx, analysis in enumerate(reversed(st.session_state.analysis_history)):
            with st.expander(f"Analysis {len(st.session_state.analysis_history) - idx}"):
                st.image(analysis['image'], use_container_width=True)
                st.write(f"**Timestamp:** {analysis['timestamp']}")
                st.write("**Analysis:**")
                st.write(analysis['result'])
    
    if uploaded_file is not None:
        st.image(uploaded_file, caption="Uploaded Image", use_container_width=True)
        
        if st.button("Analyze Image"):
            with st.spinner("Analyzing image..."):
                try:
                    # Create files dictionary with proper MIME type
                    files = {
                        "image": (
                            uploaded_file.name,
                            uploaded_file.getvalue(),
                            uploaded_file.type
                        )
                    }
                    
                    # Log request details
                    st.write("Sending request with:")
                    st.write(f"- Filename: {uploaded_file.name}")
                    st.write(f"- File type: {uploaded_file.type}")
                    st.write(f"- File size: {len(uploaded_file.getvalue())} bytes")
                    
                    result = make_request("POST", "/image", files=files)
                    
                    if "error" in result:
                        st.error(f"Analysis failed: {result['error']}")
                    else:
                        st.success("Analysis complete!")
                        st.json(result)
                        
                        # Save to analysis history
                        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                        st.session_state.analysis_history.append({
                            'image': uploaded_file,
                            'result': result,
                            'timestamp': timestamp
                        })
                except Exception as e:
                    st.error(f"Error during image analysis: {str(e)}")
                    st.write("Please try again with a different image or check if the server is running.")

# Initialize session state for image history
if 'image_history' not in st.session_state:
    st.session_state.image_history = []

with tab3:
    # POST /image-generator - Generate image
    st.header("Image Generation")
    
    col1, col2 = st.columns([2, 1])
    with col1:
        with st.form("image_gen_form"):
            prompt = st.text_area("Image description", height=100)
            size = st.selectbox("Image size", ["1024x1024", "1792x1024", "1024x1792"])
            submitted = st.form_submit_button("Generate Image")
            
            if submitted:
                if prompt.strip():
                    with st.spinner("Generating image..."):
                        try:
                            result = make_request("POST", "/image-generator", 
                                            data={"prompt": prompt, "size": size})
                            
                            if "error" in result:
                                st.error(result["error"])
                            else:
                                st.success("Image generated!")
                                
                                # Display image from URL and save to history
                                try:
                                    if 'url' in result:
                                        image_url = result['url']
                                        st.image(image_url, caption=prompt, use_container_width=True)
                                        
                                        # Add download button that links directly to the image URL
                                        st.markdown(f"[Download Image]({image_url})")
                                        
                                        # Add to image history
                                        st.session_state.image_history.append({
                                            'prompt': prompt,
                                            'url': image_url,
                                            'size': size,
                                            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
                                        })
                                    else:
                                        st.error("No image URL in response")
                                        st.error("Raw response: " + str(result))
                                except Exception as e:
                                    st.error(f"Error displaying image: {str(e)}")
                                    st.error("Raw response: " + str(result))
                        except Exception as e:
                            st.error(f"Error during image generation: {str(e)}")
                else:
                    st.warning("Please enter a description")
    
    # Display image history in sidebar
    with col2:
        st.subheader("Generated Images History")
        if st.session_state.image_history:
            if st.button("Clear Image History"):
                st.session_state.image_history = []
                st.rerun()
            
            for idx, img in enumerate(reversed(st.session_state.image_history)):
                with st.expander(f"Image {len(st.session_state.image_history) - idx}"):
                    st.markdown(f"**Prompt:** {img['prompt']}")
                    st.markdown(f"**Size:** {img['size']}")
                    st.markdown(f"**Generated:** {img['timestamp']}")
                    st.image(img['url'], caption=img['prompt'], use_container_width=True)
                    st.markdown(f"[Download]({img['url']})")
        else:
            st.info("No images generated yet")

# Sidebar with connection info and API setup
with st.sidebar:
    st.header("🔌 Connection Info")
    st.write(f"API Base URL: {API_BASE_URL}")
    
    if st.button("🔄 Check API Status"):
        try:
            response = requests.get(API_BASE_URL)
            if response.status_code == 200:
                st.success("API is reachable")
            else:
                st.error(f"API returned status {response.status_code}")
        except requests.exceptions.RequestException as e:
            st.error(f"API connection failed: {str(e)}")
    
    st.markdown("---")
    st.markdown("### 🔑 API Key Setup")
    st.markdown("To use all features, you need to set up the following API keys:")
    
    with st.expander("🔑 Required API Keys"):
        st.markdown("**1. 🤖 Groq API Key** (for Chat and Image Analysis)")
        st.markdown("- Get your key from [Groq Cloud](https://console.groq.com)")
        st.markdown("- Set the environment variable: `GROQ_API_KEY`")
        
        st.markdown("**2. 🎨 Azure OpenAI API Key** (for Image Generation)")
        st.markdown("- Get your key from [Azure OpenAI](https://portal.azure.com)")
        st.markdown("- Set the environment variable: `AZURE_OPENAI_API_KEY`")
    
    st.markdown("---")
    st.markdown("### 👨‍💻 Created By")
    st.markdown("🚀 [Amul Thantharate](https://www.linkedin.com/in/amul-thantharate)")
    st.markdown("⭐ [GitHub](https://github.com/Amul-Thantharate)")