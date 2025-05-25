const fs = require('fs');
co// Add to your IntelligentRouter class
const { DuplicateDetectionManager } = require('./duplicate-detection-manager');

class IntelligentRouter {
  constructor() {
    // ... existing code ...
    this.duplicateManager = new DuplicateDetectionManager();
  }

  async initialize() {
    // ... existing code ...
    await this.duplicateManager.initialize();
  }

  async determineRoute(content, contentType, options = {}) {
    try {
      // Check for duplicates FIRST
      const duplicateCheck = await this.duplicateManager.checkIfProcessed({
        title: content.title || '',
        content: content,
        url: options.source_url || '',
        tags: options.tags || []
      });

      if (duplicateCheck.is_duplicate) {
        if (duplicateCheck.should_reprocess?.should_reprocess) {
          this.logger.info(`Reprocessing content: ${duplicateCheck.should_reprocess.reason}`);
          // Continue with normal routing
        } else {
          this.logger.info('Skipping duplicate content - already processed acceptably');
          return {
            route_to: 'cache',
            model: 'cached_result',
            reasoning: `Duplicate content skipped: ${duplicateCheck.should_reprocess?.reason || 'already processed'}`,
            cached_result: duplicateCheck.cached_result,
            skip_processing: true
          };
        }
      }

      // Continue with your existing routing logic...
      const complexity = await this.analyzeComplexity(content, contentType);
      const classification = await this.classifyContent(content, contentType);
      const routingDecision = await this.applyRoutingRules(content, complexity, classification, options);
      const optimizedDecision = await this.optimizeRouting(routingDecision, options);
      
      return optimizedDecision;
      
    } catch (error) {
      this.logger.error('Routing determination failed:', error);
      return this.getFallbackRoute(contentType);
    }
  }
}

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
