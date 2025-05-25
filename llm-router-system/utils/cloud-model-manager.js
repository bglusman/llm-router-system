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
