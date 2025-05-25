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
