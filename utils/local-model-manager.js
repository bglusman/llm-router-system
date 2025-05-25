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
