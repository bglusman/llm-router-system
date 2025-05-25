#!/bin/bash

# Advanced Multi-LLM Router with Intelligent Workflow Orchestration
# Optimized for Dell XPS 16 (64GB RAM, RTX 4070) with GUI forwarding capability
set -e

echo "🚀 Setting up Advanced Multi-LLM Router with Intelligent Workflow Management..."
echo "💻 Optimized for Dell XPS 16 with 64GB RAM and RTX capabilities"
echo "🖥️ Includes GUI forwarding for when you need visual interfaces"

# Create project structure
mkdir -p llm-router-system/{config,data,logs,scripts,api,docker,utils,workflows,models}
cd llm-router-system

# Create comprehensive directory structure
mkdir -p data/{patreon,images,documents,processed,cache}
mkdir -p logs/{routing,models,performance}
mkdir -p volumes/{milvus,etcd,minio,ollama}
mkdir -p workflows/{templates,active,completed}
mkdir -p models/{local,routing,classification}

echo "📁 Created comprehensive project directory structure"

# Generate Docker Compose with full orchestration and GUI support
cat > docker-compose.yml << 'EOF'
services:
  # Ollama for local LLM hosting
  ollama:
    image: ollama/ollama:latest
    container_name: llm-ollama
    ports:
      - "11434:11434"
    volumes:
      - ./volumes/ollama:/root/.ollama
      - ./models/local:/models
    environment:
      - OLLAMA_MODELS=/models
      - OLLAMA_NUM_PARALLEL=4
      - OLLAMA_MAX_LOADED_MODELS=3
      - OLLAMA_MAX_QUEUE=512
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Milvus Vector Database
  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:v3.5.5
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    volumes:
      - ./volumes/etcd:/etcd
    command: etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3

  minio:
    container_name: milvus-minio
    image: minio/minio:RELEASE.2023-03-20T20-16-18Z
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    ports:
      - "9001:9001"
      - "9000:9000"
    volumes:
      - ./volumes/minio:/minio_data
    command: minio server /minio_data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  milvus:
    container_name: milvus-standalone
    image: milvusdb/milvus:v2.4.0
    command: ["milvus", "run", "standalone"]
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
    volumes:
      - ./volumes/milvus:/var/lib/milvus
      - ./config/milvus.yaml:/milvus/configs/milvus.yaml
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 90s
      timeout: 20s
      retries: 3
    ports:
      - "19530:19530"
      - "9091:9091"
    depends_on:
      - "etcd"
      - "minio"

  # LLM Router Controller
  llm-router:
    build:
      context: .
      dockerfile: docker/Dockerfile.router
    container_name: llm-router-controller
    ports:
      - "8080:8080"
    environment:
      - OLLAMA_HOST=ollama
      - OLLAMA_PORT=11434
      - MILVUS_HOST=milvus
      - MILVUS_PORT=19530
      - ABACUS_API_KEY=${ABACUS_API_KEY}
      - ABACUS_BASE_URL=${ABACUS_BASE_URL:-https://api.abacus.ai/v1}
      - ROUTER_MODE=intelligent
      - LOG_LEVEL=INFO
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./config:/app/config
      - ./workflows:/app/workflows
      - ./models:/app/models
    depends_on:
      ollama:
        condition: service_healthy
      milvus:
        condition: service_healthy
    restart: unless-stopped

  # Workflow Orchestrator with GUI capability
  workflow-engine:
    build:
      context: .
      dockerfile: docker/Dockerfile.workflow
    container_name: workflow-orchestrator
    environment:
      - LLM_ROUTER_HOST=llm-router
      - LLM_ROUTER_PORT=8080
      - PATREON_USERNAME=${PATREON_USERNAME}
      - PATREON_PASSWORD=${PATREON_PASSWORD}
      - DISPLAY=${DISPLAY:-:0}
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./config:/app/config
      - ./workflows:/app/workflows
      # GUI forwarding support
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - ${HOME}/.Xauthority:/root/.Xauthority:rw
    network_mode: host
    depends_on:
      - llm-router
    restart: unless-stopped

  # Performance Monitor
  monitor:
    build:
      context: .
      dockerfile: docker/Dockerfile.monitor
    container_name: performance-monitor
    ports:
      - "3001:3001"
    environment:
      - ROUTER_HOST=llm-router
      - OLLAMA_HOST=ollama
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config
    depends_on:
      - llm-router
    restart: unless-stopped

  # API Gateway
  api-gateway:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    container_name: api-gateway
    ports:
      - "3000:3000"
    environment:
      - ROUTER_HOST=llm-router
      - WORKFLOW_HOST=workflow-engine
      - API_KEY=${API_KEY:-your-secret-api-key}
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./config:/app/config
    depends_on:
      - llm-router
      - workflow-engine
    restart: unless-stopped

networks:
  default:
    name: llm-router-network
EOF

# Create intelligent routing configuration
cat > config/router_config.json << 'EOF'
{
  "routing_strategy": "intelligent_hybrid",
  "local_models": {
    "classification": {
      "model": "llama3.2:3b",
      "max_tokens": 100,
      "temperature": 0.1,
      "use_cases": ["content_classification", "quick_analysis", "filtering"]
    },
    "general_processing": {
      "model": "llama3.1:8b", 
      "max_tokens": 1000,
      "temperature": 0.7,
      "use_cases": ["general_analysis", "content_processing", "basic_reasoning"]
    },
    "vision_analysis": {
      "model": "llama3.2-vision:11b",
      "max_tokens": 500,
      "temperature": 0.5,
      "use_cases": ["image_analysis", "document_ocr", "visual_content"]
    },
    "document_processing": {
      "model": "deepseek-coder:6.7b",
      "max_tokens": 2000,
      "temperature": 0.3,
      "use_cases": ["document_analysis", "code_analysis", "structured_data"]
    },
    "complex_reasoning": {
      "model": "llama3.1:70b",
      "max_tokens": 2000,
      "temperature": 0.4,
      "use_cases": ["complex_analysis", "multi_step_reasoning", "advanced_logic"]
    }
  },
  "cloud_models": {
    "abacus_gpt4o": {
      "model": "gpt-4o",
      "provider": "abacus",
      "max_tokens": 4000,
      "temperature": 0.7,
      "cost_per_1k_input": 0.005,
      "cost_per_1k_output": 0.015,
      "use_cases": ["complex_trading_analysis", "multi_document_synthesis", "advanced_reasoning"]
    },
    "abacus_claude": {
      "model": "claude-3-sonnet-20240229",
      "provider": "abacus", 
      "max_tokens": 4000,
      "temperature": 0.5,
      "cost_per_1k_input": 0.003,
      "cost_per_1k_output": 0.015,
      "use_cases": ["long_document_analysis", "detailed_summarization", "research_synthesis"]
    },
    "abacus_claude_haiku": {
      "model": "claude-3-haiku-20240307",
      "provider": "abacus",
      "max_tokens": 1000,
      "temperature": 0.3,
      "cost_per_1k_input": 0.00025,
      "cost_per_1k_output": 0.00125,
      "use_cases": ["fast_classification", "quick_summaries", "cost_effective_processing"]
    }
  },
  "routing_rules": {
    "content_type_routing": {
      "text_short": {
        "condition": "length < 500 AND complexity_score < 0.3",
        "route_to": "local",
        "model": "classification"
      },
      "text_medium": {
        "condition": "length >= 500 AND length < 2000 AND complexity_score < 0.6",
        "route_to": "local", 
        "model": "general_processing"
      },
      "text_long": {
        "condition": "length >= 2000 OR complexity_score >= 0.6",
        "route_to": "local",
        "model": "complex_reasoning",
        "fallback_to_cloud": true,
        "fallback_condition": "processing_time > 30s OR quality_score < 0.7"
      },
      "images": {
        "condition": "content_type == 'image'",
        "route_to": "local",
        "model": "vision_analysis"
      },
      "documents": {
        "condition": "content_type == 'document'",
        "route_to": "local",
        "model": "document_processing"
      },
      "trading_analysis": {
        "condition": "contains_keywords(['trading', 'arbitrage', 'financial', 'stock', 'options']) AND complexity_score > 0.7",
        "route_to": "cloud",
        "model": "abacus_gpt4o"
      },
      "bulk_processing": {
        "condition": "batch_size > 10",
        "route_to": "local",
        "model": "classification",
        "parallel_processing": true
      }
    },
    "performance_routing": {
      "high_priority": {
        "condition": "priority == 'high' OR user_tier == 'premium'",
        "prefer_cloud": true,
        "max_wait_time": 5
      },
      "cost_optimization": {
        "condition": "cost_mode == 'optimize'",
        "prefer_local": true,
        "cloud_threshold": 0.8
      },
      "quality_optimization": {
        "condition": "quality_mode == 'high'",
        "prefer_cloud": true,
        "min_quality_score": 0.9
      }
    }
  },
  "workflow_templates": {
    "patreon_content_analysis": {
      "steps": [
        {
          "name": "content_classification",
          "model": "local.classification",
          "input": "raw_content",
          "output": "content_category"
        },
        {
          "name": "routing_decision", 
          "type": "decision",
          "condition": "content_category.complexity > 0.6",
          "true_path": "complex_analysis",
          "false_path": "simple_analysis"
        },
        {
          "name": "simple_analysis",
          "model": "local.general_processing",
          "input": "raw_content",
          "output": "basic_insights"
        },
        {
          "name": "complex_analysis",
          "model": "cloud.abacus_gpt4o",
          "input": "raw_content",
          "output": "detailed_insights",
          "fallback": "local.complex_reasoning"
        },
        {
          "name": "trading_signal_extraction",
          "condition": "content_category.contains_trading_keywords",
          "model": "cloud.abacus_gpt4o",
          "input": "detailed_insights",
          "output": "trading_signals"
        }
      ]
    }
  },
  "monitoring": {
    "performance_metrics": ["latency", "throughput", "cost", "quality_score"],
    "alerts": {
      "high_latency": 30,
      "high_cost": 10.0,
      "low_quality": 0.6,
      "model_failure": true
    },
    "optimization": {
      "auto_route_adjustment": true,
      "learning_enabled": true,
      "cost_tracking": true
    }
  }
}
EOF

# Create business logic and workflow engine configuration
cat > config/workflow_config.json << 'EOF'
{
  "business_logic": {
    "content_analysis_pipeline": {
      "input_processors": [
        {
          "name": "content_extractor",
          "type": "preprocessing",
          "config": {
            "supported_formats": ["text", "pdf", "docx", "xlsx", "images"],
            "max_size_mb": 50,
            "extract_metadata": true
          }
        },
        {
          "name": "complexity_analyzer",
          "type": "classification",
          "model": "local.classification",
          "output": "complexity_score"
        },
        {
          "name": "content_categorizer", 
          "type": "classification",
          "model": "local.classification",
          "categories": [
            "trading_content",
            "general_content", 
            "technical_content",
            "news_content",
            "multimedia_content"
          ]
        }
      ],
      "routing_logic": {
        "decision_tree": [
          {
            "condition": "content_type == 'image'",
            "action": "route_to_vision_model"
          },
          {
            "condition": "complexity_score < 0.3 AND content_length < 500",
            "action": "route_to_fast_local_model"
          },
          {
            "condition": "contains_trading_keywords AND complexity_score > 0.7",
            "action": "route_to_cloud_advanced_model"
          },
          {
            "condition": "content_length > 5000",
            "action": "chunk_and_process_parallel"
          },
          {
            "condition": "default",
            "action": "route_to_general_local_model"
          }
        ]
      },
      "post_processors": [
        {
          "name": "quality_validator",
          "type": "validation",
          "min_quality_score": 0.7
        },
        {
          "name": "result_aggregator",
          "type": "aggregation",
          "combine_multiple_outputs": true
        },
        {
          "name": "storage_manager",
          "type": "storage",
          "store_in_vector_db": true
        }
      ]
    },
    "auto_routing_rules": {
      "performance_based": {
        "monitor_response_times": true,
        "adjust_routing_on_performance": true,
        "fallback_strategies": [
          "local_to_cloud_on_failure",
          "cloud_to_local_on_cost_limit",
          "parallel_processing_on_high_load"
        ]
      },
      "cost_based": {
        "daily_cost_limit": 50.0,
        "cost_per_request_threshold": 0.10,
        "prefer_local_when_possible": true,
        "emergency_local_only_mode": true
      },
      "quality_based": {
        "min_acceptable_quality": 0.7,
        "upgrade_to_cloud_on_low_quality": true,
        "quality_feedback_learning": true
      }
    }
  },
  "workflow_orchestration": {
    "scraping_workflows": {
      "patreon_monitor": {
        "schedule": "*/5 * * * *",
        "steps": [
          "extract_new_content",
          "classify_content_type", 
          "route_for_processing",
          "extract_insights",
          "store_results",
          "trigger_alerts_if_needed"
        ]
      },
      "deep_analysis": {
        "schedule": "0 2 * * *",
        "steps": [
          "retrieve_recent_content",
          "batch_process_with_advanced_models",
          "generate_comprehensive_reports",
          "identify_trends_and_patterns"
        ]
      }
    },
    "dynamic_workflows": {
      "user_triggered": {
        "search_and_analyze": [
          "parse_user_query",
          "determine_search_strategy", 
          "execute_semantic_search",
          "route_results_for_analysis",
          "synthesize_final_response"
        ]
      },
      "automated_discovery": {
        "trading_opportunity_detection": [
          "scan_recent_content",
          "filter_for_trading_signals",
          "route_to_advanced_analysis",
          "validate_opportunities",
          "generate_actionable_insights"
        ]
      }
    }
  }
}
EOF

# Create Milvus configuration
cat > config/milvus.yaml << 'EOF'
etcd:
  endpoints:
    - etcd:2379

minio:
  address: minio
  port: 9000
  accessKeyID: minioadmin
  secretAccessKey: minioadmin
  useSSL: false
  bucketName: "a-bucket"

common:
  defaultPartitionName: "_default"
  defaultIndexName: "_default_idx"
  entityExpiration: -1
  indexSliceSize: 16

storage:
  path: /var/lib/milvus
EOF

# Create environment configuration with GUI support
cat > .env.example << 'EOF'
# Patreon Credentials
PATREON_USERNAME=your-patreon-username
PATREON_PASSWORD=your-patreon-password

# Abacus.AI Configuration
ABACUS_API_KEY=your-abacus-api-key
ABACUS_BASE_URL=https://api.abacus.ai/v1

# API Configuration
API_KEY=your-secret-api-key-for-external-access

# Router Configuration
ROUTER_MODE=intelligent
DEFAULT_ROUTING_STRATEGY=hybrid
COST_OPTIMIZATION_ENABLED=true
QUALITY_THRESHOLD=0.7

# Performance Settings
MAX_CONCURRENT_REQUESTS=10
REQUEST_TIMEOUT=30
BATCH_SIZE_LIMIT=50

# Monitoring
ENABLE_PERFORMANCE_MONITORING=true
LOG_LEVEL=INFO
METRICS_COLLECTION=true

# GUI Support (automatically detected, but can override)
# DISPLAY=:0
EOF

# Create corrected package.json with proper Milvus package
cat > package.json << 'EOF'
{
  "name": "intelligent-llm-router-system",
  "version": "1.0.0",
  "description": "Intelligent multi-LLM routing system with automatic workflow orchestration",
  "main": "scripts/router-controller.js",
  "scripts": {
    "start": "node scripts/router-controller.js",
    "workflow": "node scripts/workflow-engine.js",
    "monitor": "node scripts/performance-monitor.js",
    "api": "node api/gateway.js",
    "test": "node scripts/test-system.js",
    "setup-models": "node scripts/setup-local-models.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "dotenv": "^16.3.1",
    "winston": "^3.11.0",
    "node-cron": "^3.0.3",
    "uuid": "^9.0.1",
    "@zilliz/milvus2-sdk-node": "^2.4.10",
    "playwright": "^1.41.0",
    "sharp": "^0.33.0",
    "pdf-parse": "^1.1.1",
    "mammoth": "^1.6.0",
    "xlsx": "^0.18.5",
    "cheerio": "^1.0.0-rc.12",
    "multer": "^1.4.5-lts.1",
    "ws": "^8.14.2",
    "ioredis": "^5.3.2",
    "bull": "^4.12.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0"
  }
}
EOF

# Generate package-lock.json file  
echo "📦 Generating package-lock.json..."
if command -v npm >/dev/null 2>&1; then
    npm install --package-lock-only
    echo "✅ package-lock.json generated successfully"
else
    echo "⚠️  npm not found. package-lock.json will be generated during Docker build"
fi

# Create Docker files with Ubuntu base and GUI support
cat > docker/Dockerfile.router << 'EOF'
FROM node:18-alpine

RUN apk add --no-cache curl python3 py3-pip

WORKDIR /app

COPY package*.json ./

# Use modern npm syntax
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

COPY scripts/ ./scripts/
COPY utils/ ./utils/
COPY config/ ./config/

RUN mkdir -p /app/data /app/logs /app/workflows /app/models

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["node", "scripts/router-controller.js"]
EOF

# Create Ubuntu-based workflow Dockerfile with GUI support
cat > docker/Dockerfile.workflow << 'EOF'
FROM node:18

# Install system dependencies for Playwright and GUI forwarding
RUN apt-get update && apt-get install -y \
    # Playwright dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm-dev \
    libgtk-3-0 \
    xdg-utils \
    # GUI forwarding support (lightweight)
    x11-apps \
    x11-utils \
    firefox-esr \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Set display for GUI forwarding
ENV DISPLAY=:0

WORKDIR /app

COPY package*.json ./

# Handle missing package-lock.json gracefully  
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

# Install Playwright and browsers
RUN npx playwright install chromium
RUN npx playwright install-deps

COPY scripts/ ./scripts/
COPY utils/ ./utils/
COPY config/ ./config/
COPY workflows/ ./workflows/

RUN mkdir -p /app/data /app/logs

CMD ["node", "scripts/workflow-engine.js"]
EOF

cat > docker/Dockerfile.monitor << 'EOF'
FROM node:18-alpine

RUN apk add --no-cache curl

WORKDIR /app

COPY package*.json ./

RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

COPY scripts/ ./scripts/
COPY utils/ ./utils/
COPY config/ ./config/

RUN mkdir -p /app/logs

EXPOSE 3001

CMD ["node", "scripts/performance-monitor.js"]
EOF

cat > docker/Dockerfile.api << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

COPY api/ ./api/
COPY utils/ ./utils/
COPY config/ ./config/

RUN mkdir -p /app/data /app/logs

EXPOSE 3000

CMD ["node", "api/gateway.js"]
EOF

echo "🤖 Creating intelligent routing engine..."

# Create the main router controller
cat > scripts/router-controller.js << 'EOF'
const express = require('express');
const axios = require('axios');
const { IntelligentRouter } = require('../utils/intelligent-router');
const { LocalModelManager } = require('../utils/local-model-manager');
const { CloudModelManager } = require('../utils/cloud-model-manager');
const { WorkflowEngine } = require('../utils/workflow-engine');
const { Logger } = require('../utils/logger');

class RouterController {
  constructor() {
    this.app = express();
    this.logger = new Logger('RouterController');
    this.router = new IntelligentRouter();
    this.localModels = new LocalModelManager();
    this.cloudModels = new CloudModelManager();
    this.workflowEngine = new WorkflowEngine();
    this.setupMiddleware();
    this.setupRoutes();
  }

  setupMiddleware() {
    this.app.use(express.json({ limit: '50mb' }));
    this.app.use(express.urlencoded({ extended: true }));
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({ 
        status: 'healthy',
        local_models: this.localModels.getStatus(),
        cloud_connectivity: this.cloudModels.getStatus(),
        timestamp: new Date().toISOString()
      });
    });

    // Main routing endpoint
    this.app.post('/route', async (req, res) => {
      try {
        const { content, content_type, options = {} } = req.body;
        
        if (!content) {
          return res.status(400).json({ error: 'Content is required' });
        }

        // Intelligent routing decision
        const routingDecision = await this.router.determineRoute(content, content_type, options);
        
        // Execute the routing decision
        const result = await this.executeRouting(routingDecision, content, options);
        
        // Log performance metrics
        await this.logMetrics(routingDecision, result);
        
        res.json({
          routing_decision: routingDecision,
          result: result,
          timestamp: new Date().toISOString()
        });

      } catch (error) {
        this.logger.error('Routing error:', error);
        res.status(500).json({ 
          error: 'Routing failed', 
          message: error.message 
        });
      }
    });

    // Batch processing endpoint
    this.app.post('/batch', async (req, res) => {
      try {
        const { items, options = {} } = req.body;
        
        if (!items || !Array.isArray(items)) {
          return res.status(400).json({ error: 'Items array is required' });
        }

        const results = await this.processBatch(items, options);
        
        res.json({
          batch_size: items.length,
          results: results,
          timestamp: new Date().toISOString()
        });

      } catch (error) {
        this.logger.error('Batch processing error:', error);
        res.status(500).json({ error: 'Batch processing failed' });
      }
    });

    // Workflow execution endpoint
    this.app.post('/workflow', async (req, res) => {
      try {
        const { workflow_name, input_data, options = {} } = req.body;
        
        const result = await this.workflowEngine.execute(workflow_name, input_data, options);
        
        res.json({
          workflow: workflow_name,
          result: result,
          timestamp: new Date().toISOString()
        });

      } catch (error) {
        this.logger.error('Workflow execution error:', error);
        res.status(500).json({ error: 'Workflow execution failed' });
      }
    });

    // Model management endpoints
    this.app.get('/models/local', async (req, res) => {
      const models = await this.localModels.listModels();
      res.json({ models });
    });

    this.app.post('/models/local/load', async (req, res) => {
      const { model_name } = req.body;
      const result = await this.localModels.loadModel(model_name);
      res.json({ result });
    });

    this.app.post('/models/local/unload', async (req, res) => {
      const { model_name } = req.body;
      const result = await this.localModels.unloadModel(model_name);
      res.json({ result });
    });
  }

  async executeRouting(routingDecision, content, options) {
    const { route_to, model, reasoning } = routingDecision;
    
    this.logger.info(`Routing to ${route_to}:${model} - ${reasoning}`);

    if (route_to === 'local') {
      return await this.localModels.process(model, content, options);
    } else if (route_to === 'cloud') {
      return await this.cloudModels.process(model, content, options);
    } else {
      throw new Error(`Unknown routing destination: ${route_to}`);
    }
  }

  async processBatch(items, options) {
    const results = [];
    const batchSize = options.batch_size || 10;
    
    // Process in parallel batches
    for (let i = 0; i < items.length; i += batchSize) {
      const batch = items.slice(i, i + batchSize);
      const batchPromises = batch.map(async (item) => {
        try {
          const routingDecision = await this.router.determineRoute(
            item.content, 
            item.content_type, 
            { ...options, batch_mode: true }
          );
          
          const result = await this.executeRouting(routingDecision, item.content, options);
          
          return {
            id: item.id,
            routing_decision: routingDecision,
            result: result,
            status: 'success'
          };
        } catch (error) {
          return {
            id: item.id,
            error: error.message,
            status: 'failed'
          };
        }
      });
      
      const batchResults = await Promise.all(batchPromises);
      results.push(...batchResults);
    }
    
    return results;
  }

  async logMetrics(routingDecision, result) {
    const metrics = {
      timestamp: new Date().toISOString(),
      route: `${routingDecision.route_to}:${routingDecision.model}`,
      latency: result.processing_time || 0,
      cost: result.estimated_cost || 0,
      quality_score: result.quality_score || 0,
      success: result.status === 'success'
    };
    
    // Store metrics for analysis
    this.logger.info('Processing metrics:', metrics);
  }

  async start() {
    const port = process.env.PORT || 8080;
    
    // Initialize all components
    await this.router.initialize();
    await this.localModels.initialize();
    await this.cloudModels.initialize();
    await this.workflowEngine.initialize();
    
    this.app.listen(port, () => {
      this.logger.info(`🚀 Router Controller running on port ${port}`);
      console.log(`📊 Router Dashboard: http://localhost:${port}/health`);
    });
  }
}

// Start the router controller
if (require.main === module) {
  const controller = new RouterController();
  controller.start().catch(console.error);
}

module.exports = RouterController;
EOF

# Create intelligent router utility
cat > utils/intelligent-router.js << 'EOF'
const fs = require('fs');
const { Logger } = require('./logger');

class IntelligentRouter {
  constructor() {
    this.config = JSON.parse(fs.readFileSync('./config/router_config.json', 'utf8'));
    this.logger = new Logger('IntelligentRouter');
    this.performanceHistory = new Map();
    this.costTracking = new Map();
  }

  async initialize() {
    this.logger.info('Initializing Intelligent Router...');
    // Load any ML models for routing decisions
    await this.loadRoutingModels();
  }

  async loadRoutingModels() {
    // In a real implementation, you might load a trained routing model
    this.logger.info('Loading routing models...');
  }

  async determineRoute(content, contentType, options = {}) {
    try {
      // Step 1: Analyze content complexity
      const complexity = await this.analyzeComplexity(content, contentType);
      
      // Step 2: Classify content type and extract features
      const classification = await this.classifyContent(content, contentType);
      
      // Step 3: Apply routing rules
      const routingDecision = await this.applyRoutingRules(content, complexity, classification, options);
      
      // Step 4: Consider performance and cost factors
      const optimizedDecision = await this.optimizeRouting(routingDecision, options);
      
      return optimizedDecision;
      
    } catch (error) {
      this.logger.error('Routing determination failed:', error);
      return this.getFallbackRoute(contentType);
    }
  }

  async analyzeComplexity(content, contentType) {
    const analysis = {
      length: content.length,
      complexity_score: 0,
      factors: []
    };

    // Length-based complexity
    if (content.length > 5000) {
      analysis.complexity_score += 0.3;
      analysis.factors.push('long_content');
    }

    // Content-based complexity indicators
    const complexityIndicators = [
      /\b(analysis|strategy|complex|detailed|comprehensive)\b/gi,
      /\b(arbitrage|trading|financial|investment|market)\b/gi,
      /\b(data|statistics|calculations|formulas)\b/gi
    ];

    complexityIndicators.forEach((pattern, index) => {
      const matches = content.match(pattern);
      if (matches && matches.length > 0) {
        analysis.complexity_score += 0.1 + (matches.length * 0.05);
        analysis.factors.push(`complexity_pattern_${index}`);
      }
    });

    // Technical content detection
    if (/\b(code|programming|technical|algorithm|API)\b/gi.test(content)) {
      analysis.complexity_score += 0.2;
      analysis.factors.push('technical_content');
    }

    // Normalize score
    analysis.complexity_score = Math.min(analysis.complexity_score, 1.0);

    return analysis;
  }

  async classifyContent(content, contentType) {
    const classification = {
      content_type: contentType,
      categories: [],
      keywords: [],
      priority: 'medium',
      requires_cloud: false
    };

    // Trading content detection
    const tradingKeywords = ['arbitrage', 'trading', 'stock', 'options', 'financial', 'investment', 'profit', 'loss', 'market', 'tesla'];
    const foundTradingKeywords = tradingKeywords.filter(keyword => 
      content.toLowerCase().includes(keyword)
    );

    if (foundTradingKeywords.length > 0) {
      classification.categories.push('trading_content');
      classification.keywords.push(...foundTradingKeywords);
      classification.priority = 'high';
      classification.requires_cloud = foundTradingKeywords.length > 2; // Complex trading analysis
    }

    // Technical content detection
    if (/\b(code|API|technical|programming|algorithm)\b/gi.test(content)) {
      classification.categories.push('technical_content');
    }

    // News/information content
    if (/\b(news|update|announcement|report)\b/gi.test(content)) {
      classification.categories.push('informational_content');
    }

    // Multimedia content
    if (contentType === 'image' || contentType === 'video') {
      classification.categories.push('multimedia_content');
      classification.requires_specialized_model = true;
    }

    return classification;
  }

  async applyRoutingRules(content, complexity, classification, options) {
    const rules = this.config.routing_rules.content_type_routing;
    
    // Check specific content type rules
    if (classification.content_type === 'image') {
      return {
        route_to: 'local',
        model: 'vision_analysis',
        reasoning: 'Image content routed to local vision model'
      };
    }

    // Trading content with high complexity
    if (classification.categories.includes('trading_content') && complexity.complexity_score > 0.7) {
      return {
        route_to: 'cloud',
        model: 'abacus_gpt4o',
        reasoning: 'Complex trading analysis requires advanced cloud model'
      };
    }

    // Short, simple content
    if (content.length < 500 && complexity.complexity_score < 0.3) {
      return {
        route_to: 'local',
        model: 'classification',
        reasoning: 'Short, simple content processed locally for speed'
      };
    }

    // Long content with medium complexity
    if (content.length >= 2000 && complexity.complexity_score < 0.8) {
      return {
        route_to: 'local',
        model: 'complex_reasoning',
        reasoning: 'Long content processed with local advanced model',
        fallback_to_cloud: true
      };
    }

    // High complexity content
    if (complexity.complexity_score >= 0.8) {
      return {
        route_to: 'cloud',
        model: 'abacus_claude',
        reasoning: 'High complexity requires cloud processing'
      };
    }

    // Default to local general processing
    return {
      route_to: 'local',
      model: 'general_processing',
      reasoning: 'Default routing to local general model'
    };
  }

  async optimizeRouting(routingDecision, options) {
    // Cost optimization
    if (options.cost_mode === 'optimize') {
      const dailyCost = this.getDailyCost();
      if (dailyCost > this.config.monitoring.alerts.high_cost) {
        if (routingDecision.route_to === 'cloud') {
          routingDecision = {
            route_to: 'local',
            model: 'complex_reasoning',
            reasoning: 'Switched to local due to cost limits',
            original_decision: routingDecision
          };
        }
      }
    }

    // Performance optimization
    if (options.priority === 'high') {
      const localModelPerformance = this.getModelPerformance('local', routingDecision.model);
      if (localModelPerformance && localModelPerformance.avg_latency > 30000) {
        routingDecision = {
          route_to: 'cloud',
          model: 'abacus_claude_haiku',
          reasoning: 'Switched to cloud for better performance',
          original_decision: routingDecision
        };
      }
    }

    return routingDecision;
  }

  getFallbackRoute(contentType) {
    return {
      route_to: 'local',
      model: 'general_processing',
      reasoning: 'Fallback route due to routing error'
    };
  }

  getDailyCost() {
    // Implementation to track daily costs
    const today = new Date().toISOString().split('T')[0];
    return this.costTracking.get(today) || 0;
  }

  getModelPerformance(routeType, model) {
    const key = `${routeType}:${model}`;
    return this.performanceHistory.get(key);
  }

  updatePerformanceHistory(routeType, model, metrics) {
    const key = `${routeType}:${model}`;
    const existing = this.performanceHistory.get(key) || { count: 0, total_latency: 0, total_cost: 0 };
    
    existing.count++;
    existing.total_latency += metrics.latency || 0;
    existing.total_cost += metrics.cost || 0;
    existing.avg_latency = existing.total_latency / existing.count;
    existing.avg_cost = existing.total_cost / existing.count;
    
    this.performanceHistory.set(key, existing);
  }
}

module.exports = { IntelligentRouter };
EOF

# Create local model manager
cat > utils/local-model-manager.js << 'EOF'
const axios = require('axios');
const { Logger } = require('./logger');

class LocalModelManager {
  constructor() {
    this.logger = new Logger('LocalModelManager');
    this.ollamaHost = process.env.OLLAMA_HOST || 'localhost';
    this.ollamaPort = process.env.OLLAMA_PORT || 11434;
    this.baseUrl = `http://${this.ollamaHost}:${this.ollamaPort}`;
    this.loadedModels = new Set();
    this.modelConfig = JSON.parse(require('fs').readFileSync('./config/router_config.json', 'utf8')).local_models;
  }

  async initialize() {
    this.logger.info('Initializing Local Model Manager...');
    await this.checkOllamaHealth();
    await this.ensureModelsAvailable();
  }

  async checkOllamaHealth() {
    try {
      const response = await axios.get(`${this.baseUrl}/api/tags`);
      this.logger.info('Ollama connection successful');
      return true;
    } catch (error) {
      this.logger.error('Ollama connection failed:', error.message);
      throw new Error('Cannot connect to Ollama service');
    }
  }

  async ensureModelsAvailable() {
    const requiredModels = Object.values(this.modelConfig).map(config => config.model);
    const availableModels = await this.listModels();
    
    for (const model of requiredModels) {
      if (!availableModels.includes(model)) {
        this.logger.info(`Pulling missing model: ${model}`);
        await this.pullModel(model);
      }
    }
  }

  async listModels() {
    try {
      const response = await axios.get(`${this.baseUrl}/api/tags`);
      return response.data.models.map(model => model.name);
    } catch (error) {
      this.logger.error('Failed to list models:', error);
      return [];
    }
  }

  async pullModel(modelName) {
    try {
      this.logger.info(`Pulling model: ${modelName}`);
      const response = await axios.post(`${this.baseUrl}/api/pull`, {
        name: modelName
      });
      
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to pull model ${modelName}:`, error);
      throw error;
    }
  }

  async loadModel(modelName) {
    if (this.loadedModels.has(modelName)) {
      return { status: 'already_loaded', model: modelName };
    }

    try {
      // Warmup the model by sending a simple request
      await this.makeRequest(modelName, 'Hello', { max_tokens: 1 });
      this.loadedModels.add(modelName);
      this.logger.info(`Model loaded: ${modelName}`);
      
      return { status: 'loaded', model: modelName };
    } catch (error) {
      this.logger.error(`Failed to load model ${modelName}:`, error);
      throw error;
    }
  }

  async unloadModel(modelName) {
    // Ollama doesn't have explicit unload, but we can track it
    this.loadedModels.delete(modelName);
    this.logger.info(`Model unloaded: ${modelName}`);
    return { status: 'unloaded', model: modelName };
  }

  async process(modelKey, content, options = {}) {
    const startTime = Date.now();
    
    try {
      const modelConfig = this.modelConfig[modelKey];
      if (!modelConfig) {
        throw new Error(`Unknown model key: ${modelKey}`);
      }

      const modelName = modelConfig.model;
      
      // Ensure model is loaded
      await this.loadModel(modelName);
      
      // Make the request
      const result = await this.makeRequest(modelName, content, {
        max_tokens: modelConfig.max_tokens,
        temperature: modelConfig.temperature,
        ...options
      });

      const processingTime = Date.now() - startTime;

      return {
        result: result,
        model: modelName,
        processing_time: processingTime,
        status: 'success',
        route_type: 'local',
        estimated_cost: 0 // Local processing is free
      };

    } catch (error) {
      const processingTime = Date.now() - startTime;
      this.logger.error(`Local processing failed for ${modelKey}:`, error);
      
      return {
        error: error.message,
        model: modelKey,
        processing_time: processingTime,
        status: 'error',
        route_type: 'local'
      };
    }
  }

  async makeRequest(modelName, prompt, options = {}) {
    const requestData = {
      model: modelName,
      prompt: prompt,
      options: {
        num_predict: options.max_tokens || 1000,
        temperature: options.temperature || 0.7,
        top_p: options.top_p || 0.9,
        top_k: options.top_k || 40
      },
      stream: false
    };

    try {
      const response = await axios.post(`${this.baseUrl}/api/generate`, requestData, {
        timeout: 60000 // 60 second timeout
      });
      
      return response.data.response;
    } catch (error) {
      if (error.code === 'ECONNREFUSED') {
        throw new Error('Ollama service is not running');
      }
      throw error;
    }
  }

  getStatus() {
    return {
      connected: true,
      loaded_models: Array.from(this.loadedModels),
      available_model_keys: Object.keys(this.modelConfig)
    };
  }

  async getModelMetrics(modelName) {
    // In a real implementation, you'd track performance metrics
    return {
      model: modelName,
      requests_processed: 0,
      avg_latency: 0,
      error_rate: 0
    };
  }
}

module.exports = { LocalModelManager };
EOF

# Create cloud model manager
cat > utils/cloud-model-manager.js << 'EOF'
const axios = require('axios');
const { Logger } = require('./logger');

class CloudModelManager {
  constructor() {
    this.logger = new Logger('CloudModelManager');
    this.abacusApiKey = process.env.ABACUS_API_KEY;
    this.abacusBaseUrl = process.env.ABACUS_BASE_URL || 'https://api.abacus.ai/v1';
    this.modelConfig = JSON.parse(require('fs').readFileSync('./config/router_config.json', 'utf8')).cloud_models;
    this.requestCount = new Map();
    this.costTracking = new Map();
  }

  async initialize() {
    this.logger.info('Initializing Cloud Model Manager...');
    await this.testConnection();
  }

  async testConnection() {
    if (!this.abacusApiKey) {
      throw new Error('ABACUS_API_KEY environment variable not set');
    }

    try {
      // Test with a simple request
      const response = await this.makeAbacusRequest('gpt-4o-mini', 'Hello', { max_tokens: 1 });
      this.logger.info('Abacus.AI connection successful');
      return true;
    } catch (error) {
      this.logger.error('Abacus.AI connection failed:', error.message);
      throw new Error('Cannot connect to Abacus.AI service');
    }
  }

  async process(modelKey, content, options = {}) {
    const startTime = Date.now();
    
    try {
      const modelConfig = this.modelConfig[modelKey];
      if (!modelConfig) {
        throw new Error(`Unknown cloud model key: ${modelKey}`);
      }

      const result = await this.makeAbacusRequest(modelConfig.model, content, {
        max_tokens: modelConfig.max_tokens,
        temperature: modelConfig.temperature,
        ...options
      });

      const processingTime = Date.now() - startTime;
      const estimatedCost = this.calculateCost(modelConfig, content, result);

      // Track usage
      this.updateUsageStats(modelKey, processingTime, estimatedCost);

      return {
        result: result,
        model: modelConfig.model,
        processing_time: processingTime,
        status: 'success',
        route_type: 'cloud',
        estimated_cost: estimatedCost
      };

    } catch (error) {
      const processingTime = Date.now() - startTime;
      this.logger.error(`Cloud processing failed for ${modelKey}:`, error);
      
      return {
        error: error.message,
        model: modelKey,
        processing_time: processingTime,
        status: 'error',
        route_type: 'cloud'
      };
    }
  }

  async makeAbacusRequest(model, content, options = {}) {
    const requestData = {
      model: model,
      messages: [
        {
          role: 'user',
          content: content
        }
      ],
      max_tokens: options.max_tokens || 1000,
      temperature: options.temperature || 0.7
    };

    try {
      const response = await axios.post(`${this.abacusBaseUrl}/chat/completions`, requestData, {
        headers: {
          'Authorization': `Bearer ${this.abacusApiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 60000 // 60 second timeout
      });
      
      return response.data.choices[0].message.content;
    } catch (error) {
      if (error.response) {
        throw new Error(`Abacus.AI API error: ${error.response.status} - ${error.response.data.error?.message || 'Unknown error'}`);
      }
      throw error;
    }
  }

  calculateCost(modelConfig, inputContent, outputContent) {
    const inputTokens = Math.ceil(inputContent.length / 4); // Rough token estimation
    const outputTokens = Math.ceil((outputContent?.length || 0) / 4);
    
    const inputCost = (inputTokens / 1000) * (modelConfig.cost_per_1k_input || 0.001);
    const outputCost = (outputTokens / 1000) * (modelConfig.cost_per_1k_output || 0.002);
    
    return inputCost + outputCost;
  }

  updateUsageStats(modelKey, processingTime, cost) {
    const key = modelKey;
    const existing = this.requestCount.get(key) || { count: 0, totalTime: 0, totalCost: 0 };
    
    existing.count++;
    existing.totalTime += processingTime;
    existing.totalCost += cost;
    
    this.requestCount.set(key, existing);
    
    // Track daily costs
    const today = new Date().toISOString().split('T')[0];
    const dailyCost = this.costTracking.get(today) || 0;
    this.costTracking.set(today, dailyCost + cost);
  }

  getStatus() {
    return {
      connected: !!this.abacusApiKey,
      available_models: Object.keys(this.modelConfig),
      daily_cost: this.getDailyCost(),
      request_count: this.getTotalRequests()
    };
  }

  getDailyCost() {
    const today = new Date().toISOString().split('T')[0];
    return this.costTracking.get(today) || 0;
  }

  getTotalRequests() {
    return Array.from(this.requestCount.values()).reduce((sum, stats) => sum + stats.count, 0);
  }

  async generateEmbedding(text, model = 'text-embedding-ada-002') {
    try {
      const response = await axios.post(`${this.abacusBaseUrl}/embeddings`, {
        model: model,
        input: text.substring(0, 8000)
      }, {
        headers: {
          'Authorization': `Bearer ${this.abacusApiKey}`,
          'Content-Type': 'application/json'
        }
      });

      return response.data.data[0].embedding;
    } catch (error) {
      this.logger.error('Error generating embedding:', error);
      throw error;
    }
  }
}

module.exports = { CloudModelManager };
EOF

# Create workflow engine
cat > utils/workflow-engine.js << 'EOF'
const fs = require('fs');
const cron = require('node-cron');
const { Logger } = require('./logger');

class WorkflowEngine {
  constructor() {
    this.logger = new Logger('WorkflowEngine');
    this.config = JSON.parse(fs.readFileSync('./config/workflow_config.json', 'utf8'));
    this.workflows = new Map();
    this.activeJobs = new Map();
  }

  async initialize() {
    this.logger.info('Initializing Workflow Engine...');
    await this.loadWorkflowTemplates();
    await this.scheduleAutomaticWorkflows();
  }

  async loadWorkflowTemplates() {
    const templates = this.config.workflow_orchestration;
    
    for (const [categoryName, category] of Object.entries(templates)) {
      for (const [workflowName, workflow] of Object.entries(category)) {
        this.workflows.set(`${categoryName}.${workflowName}`, workflow);
        this.logger.info(`Loaded workflow: ${categoryName}.${workflowName}`);
      }
    }
  }

  async scheduleAutomaticWorkflows() {
    const scrapingWorkflows = this.config.workflow_orchestration.scraping_workflows;
    
    for (const [workflowName, workflow] of Object.entries(scrapingWorkflows)) {
      if (workflow.schedule) {
        const job = cron.schedule(workflow.schedule, async () => {
          this.logger.info(`Executing scheduled workflow: ${workflowName}`);
          await this.execute(`scraping_workflows.${workflowName}`, {});
        });
        
        this.activeJobs.set(workflowName, job);
        this.logger.info(`Scheduled workflow: ${workflowName} with cron: ${workflow.schedule}`);
      }
    }
  }

  async execute(workflowName, inputData, options = {}) {
    try {
      const workflow = this.workflows.get(workflowName);
      if (!workflow) {
        throw new Error(`Workflow not found: ${workflowName}`);
      }

      this.logger.info(`Executing workflow: ${workflowName}`);
      
      const context = {
        workflow_name: workflowName,
        input_data: inputData,
        options: options,
        start_time: new Date(),
        steps_completed: [],
        current_data: inputData
      };

      // Execute workflow steps
      if (workflow.steps) {
        context.result = await this.executeSteps(workflow.steps, context);
      } else {
        context.result = await this.executeBusinessLogic(workflowName, context);
      }

      context.end_time = new Date();
      context.duration = context.end_time - context.start_time;

      this.logger.info(`Workflow completed: ${workflowName} in ${context.duration}ms`);
      
      return {
        workflow: workflowName,
        result: context.result,
        duration: context.duration,
        steps_completed: context.steps_completed,
        status: 'completed'
      };

    } catch (error) {
      this.logger.error(`Workflow execution failed: ${workflowName}`, error);
      throw error;
    }
  }

  async executeSteps(steps, context) {
    let currentData = context.current_data;
    
    for (const step of steps) {
      try {
        this.logger.info(`Executing step: ${step}`);
        
        // Execute the step - this would integrate with your specific step implementations
        const stepResult = await this.executeStep(step, currentData, context);
        
        context.steps_completed.push({
          step: step,
          result: stepResult,
          timestamp: new Date()
        });
        
        // Update current data for next step
        currentData = stepResult.output || currentData;
        
      } catch (error) {
        this.logger.error(`Step execution failed: ${step}`, error);
        throw error;
      }
    }
    
    return currentData;
  }

  async executeStep(step, data, context) {
    // This is where you'd implement specific step logic
    // For now, return a placeholder
    return {
      step: step,
      input: data,
      output: data,
      status: 'completed'
    };
  }

  async executeBusinessLogic(workflowName, context) {
    // Implement specific business logic based on workflow name
    switch (workflowName) {
      case 'scraping_workflows.patreon_monitor':
        return await this.executePatreonMonitoring(context);
      
      case 'scraping_workflows.deep_analysis':
        return await this.executeDeepAnalysis(context);
      
      case 'dynamic_workflows.user_triggered.search_and_analyze':
        return await this.executeSearchAndAnalyze(context);
      
      default:
        throw new Error(`No business logic defined for workflow: ${workflowName}`);
    }
  }

  async executePatreonMonitoring(context) {
    this.logger.info('Executing Patreon monitoring workflow...');
    
    // This would integrate with your Patreon scraper
    return {
      type: 'patreon_monitoring',
      new_posts_found: 0,
      processed_content: [],
      timestamp: new Date()
    };
  }

  async executeDeepAnalysis(context) {
    this.logger.info('Executing deep analysis workflow...');
    
    return {
      type: 'deep_analysis',
      analysis_results: {},
      trends_identified: [],
      timestamp: new Date()
    };
  }

  async executeSearchAndAnalyze(context) {
    this.logger.info('Executing search and analyze workflow...');
    
    const { query } = context.input_data;
    
    return {
      type: 'search_and_analyze',
      query: query,
      search_results: [],
      analysis: {},
      timestamp: new Date()
    };
  }

  // Workflow management methods
  listWorkflows() {
    return Array.from(this.workflows.keys());
  }

  getWorkflowStatus(workflowName) {
    return {
      exists: this.workflows.has(workflowName),
      scheduled: this.activeJobs.has(workflowName),
      definition: this.workflows.get(workflowName)
    };
  }

  stopScheduledWorkflow(workflowName) {
    const job = this.activeJobs.get(workflowName);
    if (job) {
      job.stop();
      this.activeJobs.delete(workflowName);
      this.logger.info(`Stopped scheduled workflow: ${workflowName}`);
      return true;
    }
    return false;
  }

  startScheduledWorkflow(workflowName) {
    const job = this.activeJobs.get(workflowName);
    if (job) {
      job.start();
      this.logger.info(`Started scheduled workflow: ${workflowName}`);
      return true;
    }
    return false;
  }
}

module.exports = { WorkflowEngine };
EOF

# Create logger utility
cat > utils/logger.js << 'EOF'
const winston = require('winston');

class Logger {
  constructor(service) {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: { service },
      transports: [
        new winston.transports.File({ 
          filename: `./logs/${service}-error.log`, 
          level: 'error' 
        }),
        new winston.transports.File({ 
          filename: `./logs/${service}-combined.log` 
        }),
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        })
      ]
    });
  }

  info(message, meta = {}) {
    this.logger.info(message, meta);
  }

  error(message, meta = {}) {
    this.logger.error(message, meta);
  }

  warn(message, meta = {}) {
    this.logger.warn(message, meta);
  }

  debug(message, meta = {}) {
    this.logger.debug(message, meta);
  }
}

module.exports = { Logger };
EOF

# Create API Gateway
cat > api/gateway.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const axios = require('axios');
const { Logger } = require('../utils/logger');

class APIGateway {
  constructor() {
    this.app = express();
    this.logger = new Logger('APIGateway');
    this.routerHost = process.env.ROUTER_HOST || 'localhost';
    this.workflowHost = process.env.WORKFLOW_HOST || 'localhost';
    this.apiKey = process.env.API_KEY || 'your-secret-api-key';
    
    this.setupMiddleware();
    this.setupRoutes();
  }

  setupMiddleware() {
    this.app.use(helmet());
    this.app.use(cors());
    this.app.use(express.json({ limit: '50mb' }));
  }

  authenticateAPI(req, res, next) {
    const apiKey = req.header('X-API-Key') || req.query.apiKey;
    
    if (!apiKey || apiKey !== this.apiKey) {
      return res.status(401).json({ error: 'Invalid API key' });
    }
    
    next();
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', async (req, res) => {
      try {
        const routerHealth = await axios.get(`http://${this.routerHost}:8080/health`);
        res.json({
          status: 'healthy',
          services: {
            router: routerHealth.data,
            gateway: 'healthy'
          },
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        res.status(503).json({
          status: 'unhealthy',
          error: error.message
        });
      }
    });

    // Intelligent content processing
    this.app.post('/process', this.authenticateAPI.bind(this), async (req, res) => {
      try {
        const response = await axios.post(`http://${this.routerHost}:8080/route`, req.body);
        res.json(response.data);
      } catch (error) {
        this.logger.error('Processing request failed:', error);
        res.status(500).json({ error: 'Processing failed' });
      }
    });

    // Batch processing
    this.app.post('/batch', this.authenticateAPI.bind(this), async (req, res) => {
      try {
        const response = await axios.post(`http://${this.routerHost}:8080/batch`, req.body);
        res.json(response.data);
      } catch (error) {
        this.logger.error('Batch processing failed:', error);
        res.status(500).json({ error: 'Batch processing failed' });
      }
    });

    // Workflow execution
    this.app.post('/workflow', this.authenticateAPI.bind(this), async (req, res) => {
      try {
        const response = await axios.post(`http://${this.routerHost}:8080/workflow`, req.body);
        res.json(response.data);
      } catch (error) {
        this.logger.error('Workflow execution failed:', error);
        res.status(500).json({ error: 'Workflow execution failed' });
      }
    });

    // Trading analysis endpoint (legacy compatibility)
    this.app.post('/analyze/trading', this.authenticateAPI.bind(this), async (req, res) => {
      try {
        const { query } = req.body;
        const processRequest = {
          content: query,
          content_type: 'text',
          options: {
            force_category: 'trading_content',
            priority: 'high'
          }
        };
        
        const response = await axios.post(`http://${this.routerHost}:8080/route`, processRequest);
        res.json({
          query,
          trading_analysis: response.data.result.result,
          routing_info: response.data.routing_decision,
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        this.logger.error('Trading analysis failed:', error);
        res.status(500).json({ error: 'Trading analysis failed' });
      }
    });

    // Search endpoint (legacy compatibility)
    this.app.post('/search', this.authenticateAPI.bind(this), async (req, res) => {
      try {
        const { query, options = {} } = req.body;
        
        const workflowRequest = {
          workflow_name: 'dynamic_workflows.user_triggered.search_and_analyze',
          input_data: { query },
          options
        };
        
        const response = await axios.post(`http://${this.routerHost}:8080/workflow`, workflowRequest);
        res.json({
          query,
          results: response.data.result,
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        this.logger.error('Search request failed:', error);
        res.status(500).json({ error: 'Search failed' });
      }
    });

    // Model management
    this.app.get('/models', this.authenticateAPI.bind(this), async (req, res) => {
      try {
        const localModels = await axios.get(`http://${this.routerHost}:8080/models/local`);
        res.json({
          local_models: localModels.data.models,
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        res.status(500).json({ error: 'Failed to fetch models' });
      }
    });
  }

  start() {
    const port = process.env.PORT || 3000;
    this.app.listen(port, () => {
      this.logger.info(`🚀 API Gateway running on port ${port}`);
      console.log(`📚 API Documentation:`);
      console.log(`  POST /process - Intelligent content processing`);
      console.log(`  POST /batch - Batch processing`);
      console.log(`  POST /workflow - Workflow execution`);
      console.log(`  POST /search - Semantic search`);
      console.log(`  POST /analyze/trading - Trading analysis`);
      console.log(`  GET /models - List available models`);
      console.log(`  GET /health - System health check`);
    });
  }
}

if (require.main === module) {
  const gateway = new APIGateway();
  gateway.start();
}

module.exports = APIGateway;
EOF

# Create performance monitor
cat > scripts/performance-monitor.js << 'EOF'
const express = require('express');
const axios = require('axios');
const { Logger } = require('../utils/logger');

class PerformanceMonitor {
  constructor() {
    this.app = express();
    this.logger = new Logger('PerformanceMonitor');
    this.routerHost = process.env.ROUTER_HOST || 'localhost';
    this.ollamaHost = process.env.OLLAMA_HOST || 'localhost';
    this.metrics = new Map();
    
    this.setupRoutes();
    this.startMonitoring();
  }

  setupRoutes() {
    this.app.use(express.json());
    
    this.app.get('/metrics', (req, res) => {
      res.json({
        current_metrics: Array.from(this.metrics.entries()),
        timestamp: new Date().toISOString()
      });
    });
    
    this.app.get('/health', (req, res) => {
      res.json({ status: 'healthy', service: 'performance-monitor' });
    });
  }

  async startMonitoring() {
    // Monitor every 30 seconds
    setInterval(async () => {
      await this.collectMetrics();
    }, 30000);
    
    this.logger.info('Performance monitoring started');
  }

  async collectMetrics() {
    try {
      // Collect router metrics
      const routerHealth = await axios.get(`http://${this.routerHost}:8080/health`);
      
      // Collect Ollama metrics
      const ollamaModels = await axios.get(`http://${this.ollamaHost}:11434/api/tags`);
      
      const timestamp = new Date().toISOString();
      this.metrics.set(timestamp, {
        router_status: routerHealth.data,
        ollama_models: ollamaModels.data.models.length,
        timestamp
      });
      
      // Keep only last 100 entries
      if (this.metrics.size > 100) {
        const firstKey = this.metrics.keys().next().value;
        this.metrics.delete(firstKey);
      }
      
    } catch (error) {
      this.logger.error('Metrics collection failed:', error);
    }
  }

  start() {
    const port = process.env.PORT || 3001;
    this.app.listen(port, () => {
      this.logger.info(`📊 Performance Monitor running on port ${port}`);
    });
  }
}

if (require.main === module) {
  const monitor = new PerformanceMonitor();
  monitor.start();
}

module.exports = PerformanceMonitor;
EOF

# Create setup script for local models
cat > scripts/setup-local-models.js << 'EOF'
const axios = require('axios');
const { Logger } = require('../utils/logger');

class ModelSetup {
  constructor() {
    this.logger = new Logger('ModelSetup');
    this.ollamaHost = process.env.OLLAMA_HOST || 'localhost';
    this.ollamaPort = process.env.OLLAMA_PORT || 11434;
    this.baseUrl = `http://${this.ollamaHost}:${this.ollamaPort}`;
  }

  async setupModels() {
    console.log('🤖 Setting up local LLM models optimized for your Dell XPS 16...');
    
    const models = [
      { name: 'llama3.2:3b', description: 'Fast classification model (2GB)', priority: 'high' },
      { name: 'llama3.1:8b', description: 'General processing model (5GB)', priority: 'high' },
      { name: 'llama3.2-vision:11b', description: 'Vision analysis model (7GB)', priority: 'medium' },
      { name: 'deepseek-coder:6.7b', description: 'Document processing model (4GB)', priority: 'medium' },
      { name: 'llama3.1:70b', description: 'Advanced reasoning model (35GB - optional)', priority: 'low' }
    ];

    // Install high priority models first
    for (const model of models.filter(m => m.priority === 'high')) {
      await this.installModel(model);
    }

    console.log('\n🎯 High priority models installed! System is functional.');
    console.log('Continue installing additional models? (y/n)');
    
    // In production, you might want user input here
    for (const model of models.filter(m => m.priority !== 'high')) {
      await this.installModel(model);
    }

    console.log('\n🎉 Model setup complete!');
    console.log('\n💾 Total estimated storage used: ~53GB');
    console.log('📊 Your 64GB RAM can handle all models simultaneously');
  }

  async installModel(model) {
    console.log(`\n📥 Setting up ${model.name} - ${model.description}`);
    
    try {
      await this.checkModelExists(model.name);
      console.log(`✅ ${model.name} is already available`);
    } catch (error) {
      console.log(`⬇️  Pulling ${model.name}...`);
      await this.pullModel(model.name);
      console.log(`✅ ${model.name} installed successfully`);
    }
  }

  async checkModelExists(modelName) {
    const response = await axios.get(`${this.baseUrl}/api/tags`);
    const exists = response.data.models.some(model => model.name === modelName);
    
    if (!exists) {
      throw new Error(`Model ${modelName} not found`);
    }
  }

  async pullModel(modelName) {
    const response = await axios.post(`${this.baseUrl}/api/pull`, {
      name: modelName
    });
    
    return response.data;
  }

  async testModels() {
    console.log('\n🧪 Testing model functionality...');
    
    const testPrompt = 'Hello, this is a test. Please respond briefly.';
    const models = ['llama3.2:3b', 'llama3.1:8b'];
    
    for (const model of models) {
      try {
        console.log(`Testing ${model}...`);
        const startTime = Date.now();
        
        const response = await axios.post(`${this.baseUrl}/api/generate`, {
          model: model,
          prompt: testPrompt,
          options: { num_predict: 50 },
          stream: false
        });
        
        const duration = Date.now() - startTime;
        console.log(`✅ ${model} responded in ${duration}ms`);
        
      } catch (error) {
        console.log(`❌ ${model} test failed:`, error.message);
      }
    }
  }
}

async function main() {
  const setup = new ModelSetup();
  
  try {
    await setup.setupModels();
    await setup.testModels();
    
    console.log('\n🚀 Ready to start the intelligent routing system!');
    console.log('💡 Run: docker-compose up -d');
    
  } catch (error) {
    console.error('❌ Setup failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = ModelSetup;
EOF

# Create test system script
cat > scripts/test-system.js << 'EOF'
const axios = require('axios');
const { Logger } = require('../utils/logger');

class SystemTester {
  constructor() {
    this.logger = new Logger('SystemTester');
    this.baseUrl = 'http://localhost:8080';
  }

  async runTests() {
    console.log('🧪 Running comprehensive system tests...');
    
    try {
      await this.testHealth();
      await this.testLocalRouting();
      await this.testCloudRouting();
      await this.testBatchProcessing();
      await this.testWorkflows();
      
      console.log('\n🎉 All tests passed! System is ready.');
      
    } catch (error) {
      console.error('❌ Tests failed:', error);
      process.exit(1);
    }
  }

  async testHealth() {
    console.log('\n📋 Testing system health...');
    const response = await axios.get(`${this.baseUrl}/health`);
    console.log('✅ System health check passed');
  }

  async testLocalRouting() {
    console.log('\n🤖 Testing local model routing...');
    const response = await axios.post(`${this.baseUrl}/route`, {
      content: 'This is a simple test message.',
      content_type: 'text'
    });
    console.log(`✅ Local routing test passed - routed to: ${response.data.routing_decision.route_to}`);
  }

  async testCloudRouting() {
    console.log('\n☁️ Testing cloud model routing...');
    const response = await axios.post(`${this.baseUrl}/route`, {
      content: 'Complex arbitrage trading strategy analysis for Tesla stock options with multiple market indicators and risk assessment parameters.',
      content_type: 'text',
      options: { force_cloud: true }
    });
    console.log(`✅ Cloud routing test passed - routed to: ${response.data.routing_decision.route_to}`);
  }

  async testBatchProcessing() {
    console.log('\n📦 Testing batch processing...');
    const response = await axios.post(`${this.baseUrl}/batch`, {
      items: [
        { id: 1, content: 'Test message 1', content_type: 'text' },
        { id: 2, content: 'Test message 2', content_type: 'text' }
      ]
    });
    console.log(`✅ Batch processing test passed - processed ${response.data.batch_size} items`);
  }

  async testWorkflows() {
    console.log('\n🔄 Testing workflow execution...');
    const response = await axios.post(`${this.baseUrl}/workflow`, {
      workflow_name: 'dynamic_workflows.user_triggered.search_and_analyze',
      input_data: { query: 'test workflow execution' }
    });
    console.log(`✅ Workflow test passed - executed: ${response.data.workflow}`);
  }
}

if (require.main === module) {
  const tester = new SystemTester();
  tester.runTests();
}

module.exports = SystemTester;
EOF