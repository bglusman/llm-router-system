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
// Force reprocess endpoint
this.app.post('/reprocess', this.authenticateAPI.bind(this), async (req, res) => {
  try {
    const { identifier, reason = 'manual_request' } = req.body;
    
    const duplicateManager = new DuplicateDetectionManager();
    await duplicateManager.initialize();
    
    await duplicateManager.forceReprocess(identifier, reason);
    
    res.json({
      success: true,
      message: `Content marked for reprocessing: ${identifier}`,
      reason: reason,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to mark for reprocessing' });
  }
});

// Check processing status
this.app.get('/status/:identifier', this.authenticateAPI.bind(this), async (req, res) => {
  try {
    const { identifier } = req.params;
    
    const duplicateManager = new DuplicateDetectionManager();
    await duplicateManager.initialize();
    
    const status = await duplicateManager.checkIfProcessed({ url: identifier });
    
    res.json({
      identifier,
      status,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to check status' });
  }
});

module.exports = APIGateway;
