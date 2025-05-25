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
