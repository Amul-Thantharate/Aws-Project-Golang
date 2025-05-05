#!/bin/bash

# Get the ALB URL
cd terraform
ALB_URL=$(terraform output -raw alb_url)
cd ..

echo "\n======= Testing WAF Security Rules ======="

# ==========================================
# SQL Injection Tests
# ==========================================
echo "\n1. Testing SQL Injection Protection:"

# Basic SQL Injection
echo "\n1.1. Basic SQL Injection (OR 1=1):"
curl -v "$ALB_URL/api/login?user=%27OR%201%3D1--" 2>&1 | grep -A 5 "< HTTP"

# Union-based SQL Injection
echo "\n1.2. Union-based SQL Injection:"
curl -v "$ALB_URL/api/search?id=1%20UNION%20SELECT%20username,password%20FROM%20users--" 2>&1 | grep -A 5 "< HTTP"

# Time-based SQL Injection
echo "\n1.3. Time-based SQL Injection:"
curl -v "$ALB_URL/api/product?id=1%20AND%20(SELECT%20SLEEP(1))--" 2>&1 | grep -A 5 "< HTTP"

# Error-based SQL Injection
echo "\n1.4. Error-based SQL Injection:"
curl -v "$ALB_URL/api/profile?id=1%20AND%20EXTRACTVALUE(1,CONCAT(0x7e,(SELECT%20version()),0x7e))" 2>&1 | grep -A 5 "< HTTP"

# ==========================================
# XSS Tests
# ==========================================
echo "\n2. Testing XSS Protection:"

# Basic XSS
echo "\n2.1. Basic XSS (script tag):"
curl -v "$ALB_URL/api/search?q=%3Cscript%3Ealert%281%29%3C%2Fscript%3E" 2>&1 | grep -A 5 "< HTTP"

# Event Handler XSS
echo "\n2.2. Event Handler XSS:"
curl -v "$ALB_URL/api/comment?text=%3Cimg%20src%3Dx%20onerror%3Dalert%281%29%3E" 2>&1 | grep -A 5 "< HTTP"

# JavaScript URI XSS
echo "\n2.3. JavaScript URI XSS:"
curl -v "$ALB_URL/api/redirect?url=javascript%3Aalert%28document.cookie%29" 2>&1 | grep -A 5 "< HTTP"

# DOM-based XSS
echo "\n2.4. DOM-based XSS:"
curl -v "$ALB_URL/api/render?template=%3Cdiv%20id%3D%22%22%20onclick%3D%22alert%281%29%22%3EClick%20me%3C%2Fdiv%3E" 2>&1 | grep -A 5 "< HTTP"

# ==========================================
# Path Traversal/LFI Tests
# ==========================================
echo "\n3. Testing Path Traversal Protection:"

# Basic Path Traversal
echo "\n3.1. Basic Path Traversal (../etc/passwd):"
curl -v "$ALB_URL/api/file?name=..%2F..%2F..%2Fetc%2Fpasswd" 2>&1 | grep -A 5 "< HTTP"

# Double-encoded Path Traversal
echo "\n3.2. Double-encoded Path Traversal:"
curl -v "$ALB_URL/api/file?name=%252e%252e%252f%252e%252e%252fetc%252fpasswd" 2>&1 | grep -A 5 "< HTTP"

# Path Traversal with Null Byte
echo "\n3.3. Path Traversal with Null Byte:"
curl -v "$ALB_URL/api/file?name=..%2F..%2F..%2Fetc%2Fpasswd%00.txt" 2>&1 | grep -A 5 "< HTTP"

# Path Traversal with URL Validation Bypass
echo "\n3.4. Path Traversal with URL Validation Bypass:"
curl -v "$ALB_URL/api/file?name=....//....//etc/passwd" 2>&1 | grep -A 5 "< HTTP"

# ==========================================
# Admin Path Restriction Tests
# ==========================================
echo "\n4. Testing Admin Path Restriction:"

# Direct Admin Access
echo "\n4.1. Direct Admin Access:"
curl -v "$ALB_URL/admin" 2>&1 | grep -A 5 "< HTTP"

# Admin Subdirectory Access
echo "\n4.2. Admin Subdirectory Access:"
curl -v "$ALB_URL/admin/users" 2>&1 | grep -A 5 "< HTTP"

# Case-sensitivity Test
echo "\n4.3. Case-sensitivity Test:"
curl -v "$ALB_URL/AdMiN" 2>&1 | grep -A 5 "< HTTP"

# URL-encoded Admin Path
echo "\n4.4. URL-encoded Admin Path:"
curl -v "$ALB_URL/%61%64%6d%69%6e" 2>&1 | grep -A 5 "< HTTP"

# ==========================================
# Security Scanner Detection Tests
# ==========================================
echo "\n5. Testing Security Scanner Detection:"

# SQLMap Scanner
echo "\n5.1. SQLMap Scanner:"
curl -v -A "sqlmap/1.6" "$ALB_URL/" 2>&1 | grep -A 5 "< HTTP"

# Nikto Scanner
echo "\n5.2. Nikto Scanner:"
curl -v -A "Nikto/2.1.6" "$ALB_URL/" 2>&1 | grep -A 5 "< HTTP"

# Acunetix Scanner
echo "\n5.3. Acunetix Scanner:"
curl -v -A "Acunetix Web Vulnerability Scanner" "$ALB_URL/" 2>&1 | grep -A 5 "< HTTP"

# Nessus Scanner
echo "\n5.4. Nessus Scanner:"
curl -v -A "Mozilla/5.0 (Nessus)" "$ALB_URL/" 2>&1 | grep -A 5 "< HTTP"

# ==========================================
# Browser Test URLs (Copy to Browser)
# ==========================================
echo "\n6. Browser Test URLs (Copy to your browser):"
echo "\n6.1. SQL Injection Test:"
echo "$ALB_URL/api/login?user='OR%201=1--"

echo "\n6.2. XSS Test:"
echo "$ALB_URL/api/search?q=<script>alert('XSS')</script>"

echo "\n6.3. Path Traversal Test:"
echo "$ALB_URL/api/file?name=../../../etc/passwd"

echo "\n6.4. Admin Path Test:"
echo "$ALB_URL/admin"

echo "\n6.5. Normal Page (should be allowed):"
echo "$ALB_URL/"

# ==========================================
# WAF Logging Configuration Check
# ==========================================
echo "\n======= WAF Logging Configuration ======="
cd terraform
WAF_ARN=$(aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='security-acl'].ARN" --output text)
echo "WAF ARN: $WAF_ARN"

if [ -n "$WAF_ARN" ]; then
  echo "\nChecking WAF logging configuration:"
  aws wafv2 get-logging-configuration --resource-arn "$WAF_ARN" || echo "Logging not configured"
  
  echo "\nChecking WAF metrics (last 30 minutes):"
  aws cloudwatch get-metric-statistics \
    --namespace AWS/WAFV2 \
    --metric-name BlockedRequests \
    --dimensions Name=WebACL,Value=security-acl Name=Region,Value=us-east-1 \
    --start-time "$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --period 300 \
    --statistics Sum || echo "Metrics not available"
else
  echo "WAF ARN not found. Skipping logging check."
fi

echo "\n======= Test Complete ======="