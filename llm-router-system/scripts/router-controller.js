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
