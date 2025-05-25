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
