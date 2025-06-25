#!/bin/bash

# Quick Install Script for Ayyıldız Haber Ajansı
# One-command deployment for Ubuntu 24.04

echo "Ayyıldız Haber Ajansı - Quick Install"
echo "====================================="

# Make the main deployment script executable
chmod +x ubuntu24-deploy.sh

# Run the deployment
./ubuntu24-deploy.sh

echo ""
echo "Installation completed! Check the output above for your website URL and admin credentials."