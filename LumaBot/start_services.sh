#!/bin/bash

# Start the Go service in the background on port 8080
/app/lumabot &

# Start the Python/Streamlit service on port 8501 (default Streamlit port)
streamlit run /app/main.py \
    --server.port=8501 \
    --server.address=0.0.0.0 \
    --server.headless=true