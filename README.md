# Intelligent Multi-LLM Router System

Advanced multi-LLM routing system with intelligent workflow orchestration, optimized for your Dell XPS 16 (64GB RAM, RTX 4070) with hybrid local/cloud processing.

## 🚀 Features

### **🧠 Intelligent Routing**
- **Automatic Content Analysis**: Complexity scoring, content classification, keyword detection
- **Smart Model Selection**: Routes content to optimal LLM based on complexity, type, and performance
- **Cost Optimization**: Prefers local processing, only uses cloud for complex analysis
- **Performance Monitoring**: Real-time metrics and automatic route optimization

### **💻 Local LLM Integration**
- **Ollama Integration**: Seamless local model management
- **Multi-Model Support**: Classification, general processing, vision, document analysis, reasoning
- **GPU Acceleration**: Optimized for your RTX 4070
- **Sequential Loading**: Efficient memory management for your 64GB RAM

### **☁️ Cloud LLM Integration**
- **Abacus.AI Integration**: Access to GPT-4o, Claude, Gemini models
- **Cost Tracking**: Real-time cost monitoring and limits
- **Fallback Strategies**: Automatic cloud-to-local fallback on cost/performance issues

### **🔄 Workflow Orchestration**
- **Automated Workflows**: Scheduled content processing, analysis pipelines
- **Business Logic Engine**: Intelligent decision trees for content routing
- **Dynamic Workflows**: User-triggered analysis and search capabilities

## 📋 Quick Start

### 1. **Environment Setup**
# Intelligent Multi-LLM Router System

Advanced multi-LLM routing system with intelligent workflow orchestration, optimized for your Dell XPS 16 (64GB RAM, RTX 4070) with hybrid local/cloud processing.

## 🚀 Features

### **🧠 Intelligent Routing**
- **Automatic Content Analysis**: Complexity scoring, content classification, keyword detection
- **Smart Model Selection**: Routes content to optimal LLM based on complexity, type, and performance
- **Cost Optimization**: Prefers local processing, only uses cloud for complex analysis
- **Performance Monitoring**: Real-time metrics and automatic route optimization

### **💻 Local LLM Integration**
- **Ollama Integration**: Seamless local model management
- **Multi-Model Support**: Classification, general processing, vision, document analysis, reasoning
- **GPU Acceleration**: Optimized for your RTX 4070
- **Sequential Loading**: Efficient memory management for your 64GB RAM

### **☁️ Cloud LLM Integration**
- **Abacus.AI Integration**: Access to GPT-4o, Claude, Gemini models
- **Cost Tracking**: Real-time cost monitoring and limits
- **Fallback Strategies**: Automatic cloud-to-local fallback on cost/performance issues

### **🔄 Workflow Orchestration**
- **Automated Workflows**: Scheduled content processing, analysis pipelines
- **Business Logic Engine**: Intelligent decision trees for content routing
- **Dynamic Workflows**: User-triggered analysis and search capabilities

## 📋 Quick Start

### 1. **Environment Setup**
cp .env.example .env

### 2. **Start All Services**
docker-compose up -d

### 3. **Verify Setup**
docker-compose ps

### 4. **Test API**
curl http://localhost:3000/health

### 5. **Access Documentation**
http://localhost:3000/docs

### 6. **Access API Gateway**
http://localhost:3000/api
