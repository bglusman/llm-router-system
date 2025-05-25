const crypto = require('crypto');
const { Logger } = require('./logger');

class DuplicateDetectionManager {
  constructor() {
    this.logger = new Logger('DuplicateDetection');
    this.config = JSON.parse(require('fs').readFileSync('./config/router_config.json', 'utf8')).duplicate_detection;
    this.processedContent = new Map(); // In-memory cache
    this.contentDatabase = null; // Would connect to your database
  }

  async initialize() {
    this.logger.info('Initializing Duplicate Detection Manager...');
    await this.loadProcessedContent();
  }

  // Generate content fingerprint
  generateContentFingerprint(content) {
    const fingerprintData = {
      // Extract Patreon post ID from URL
      post_id: this.extractPatreonPostId(content.url),
      // Extract video ID if present
      video_id: this.extractVideoId(content.content),
      // Normalize title (remove extra spaces, etc.)
      title: this.normalizeText(content.title),
      // Create content hash
      content_hash: this.createContentHash(content.content),
      // Extract tags from your screenshots (Bitcoin, SBR, etc.)
      tags: this.extractAndNormalizeTags(content.tags || []),
      // URL normalization
      normalized_url: this.normalizeUrl(content.url)
    };

    // Create primary fingerprint
    const primaryData = `${fingerprintData.post_id}|${fingerprintData.title}|${fingerprintData.content_hash}`;
    const primaryFingerprint = crypto.createHash('sha256').update(primaryData).digest('hex');

    return {
      primary_fingerprint: primaryFingerprint,
      secondary_fingerprint: this.createSecondaryFingerprint(fingerprintData),
      metadata: fingerprintData
    };
  }

  // Check if content has been processed
  async checkIfProcessed(content) {
    const fingerprint = this.generateContentFingerprint(content);
    
    // Check in-memory cache first
    if (this.processedContent.has(fingerprint.primary_fingerprint)) {
      const cachedInfo = this.processedContent.get(fingerprint.primary_fingerprint);
      return {
        is_duplicate: true,
        processing_status: cachedInfo.status,
        last_processed: cachedInfo.last_processed,
        quality_score: cachedInfo.quality_score,
        should_reprocess: this.shouldReprocess(cachedInfo),
        cached_result: cachedInfo.result
      };
    }

    // Check database
    const dbResult = await this.checkDatabase(fingerprint);
    if (dbResult.found) {
      // Cache the result
      this.processedContent.set(fingerprint.primary_fingerprint, dbResult.data);
      
      return {
        is_duplicate: true,
        processing_status: dbResult.data.status,
        last_processed: dbResult.data.last_processed,
        quality_score: dbResult.data.quality_score,
        should_reprocess: this.shouldReprocess(dbResult.data),
        cached_result: dbResult.data.result
      };
    }

    return {
      is_duplicate: false,
      fingerprint: fingerprint,
      should_process: true
    };
  }

  // Determine if content should be reprocessed
  shouldReprocess(processedInfo) {
    // Force reprocess flag set
    if (processedInfo.force_reprocess_flag) {
      return { should_reprocess: true, reason: 'force_reprocess_requested' };
    }

    // Failed processing should be retried
    if (processedInfo.status === 'failed' && processedInfo.error_count < 3) {
      return { should_reprocess: true, reason: 'retry_failed_processing' };
    }

    // Quality score too low and new models available
    if (processedInfo.quality_score < 0.7 && this.hasNewerProcessingVersion(processedInfo.processing_version)) {
      return { should_reprocess: true, reason: 'quality_improvement_available' };
    }

    // Priority tags detected in old content
    if (this.hasPriorityTagsNeedingReprocessing(processedInfo)) {
      return { should_reprocess: true, reason: 'priority_tags_detected' };
    }

    return { should_reprocess: false, reason: 'content_acceptable' };
  }

  // Mark content for processing
  async markAsProcessing(fingerprint, content) {
    const processingInfo = {
      content_hash: fingerprint.primary_fingerprint,
      content_id: fingerprint.metadata.post_id || fingerprint.metadata.video_id,
      processing_status: 'processing',
      started_processing: new Date().toISOString(),
      processing_version: this.getCurrentProcessingVersion(),
      content_metadata: fingerprint.metadata,
      original_content: content
    };

    this.processedContent.set(fingerprint.primary_fingerprint, processingInfo);
    await this.saveToDatabase(processingInfo);
    
    return processingInfo;
  }

  // Mark content as completed
  async markAsCompleted(fingerprint, result, qualityScore = 0.8) {
    const completedInfo = {
      content_hash: fingerprint.primary_fingerprint,
      processing_status: 'completed',
      last_processed: new Date().toISOString(),
      quality_score: qualityScore,
      processing_version: this.getCurrentProcessingVersion(),
      result: result,
      force_reprocess_flag: false,
      error_count: 0
    };

    this.processedContent.set(fingerprint.primary_fingerprint, completedInfo);
    await this.saveToDatabase(completedInfo);
    
    this.logger.info(`Content marked as completed: ${fingerprint.primary_fingerprint.substring(0, 8)}...`);
  }

  // Force reprocess specific content
  async forceReprocess(identifier, reason = 'manual_request') {
    // identifier could be URL, post_id, or hash
    const contentHashes = await this.findContentByIdentifier(identifier);
    
    for (const hash of contentHashes) {
      if (this.processedContent.has(hash)) {
        const info = this.processedContent.get(hash);
        info.force_reprocess_flag = true;
        info.processing_status = 'needs_reprocessing';
        info.reprocess_reason = reason;
        
        await this.saveToDatabase(info);
        this.logger.info(`Marked for reprocessing: ${hash.substring(0, 8)}... (${reason})`);
      }
    }
  }

  // Helper methods for your InvestAnswers use case
  extractPatreonPostId(url) {
    if (!url) return null;
    
    // Extract from URLs like: https://www.patreon.com/InvestAnswers/posts/12345
    const match = url.match(/\/posts\/(\d+)/);
    if (match) return match[1];
    
    // Extract from filter URLs: https://www.patreon.com/InvestAnswers/posts?filters[tag]=Bitcoin
    const filterMatch = url.match(/patreon\.com\/([^\/]+)\/posts/);
    if (filterMatch) return `${filterMatch[1]}_filtered`;
    
    return crypto.createHash('md5').update(url).digest('hex').substring(0, 8);
  }

  extractVideoId(content) {
    if (!content) return null;
    
    // Extract YouTube video ID from your live stream format
    // "Live at 12:20pm Pacific: https://youtube.com/live/hmhtbtKJ6ws"
    const liveMatch = content.match(/youtube\.com\/live\/([^\\s]+)/);
    if (liveMatch) return liveMatch[1];
    
    // Regular YouTube links
    const videoMatch = content.match(/youtube\.com\/watch\?v=([^&\\s]+)/);
    if (videoMatch) return videoMatch[1];
    
    const shortMatch = content.match(/youtu\.be\/([^\\s]+)/);
    if (shortMatch) return shortMatch[1];
    
    return null;
  }

  extractAndNormalizeTags(tags) {
    // Normalize tags like "Bitcoin", "SBR", "Texas" from your screenshots
    return tags.map(tag => tag.toLowerCase().trim()).sort();
  }

  normalizeUrl(url) {
    if (!url) return '';
    
    // Remove tracking parameters, normalize filters
    const cleanUrl = url.split('?')[0];
    return cleanUrl.toLowerCase();
  }

  createContentHash(content) {
    if (!content) return '';
    
    // Normalize content for hashing
    const normalized = content
      .replace(/\s+/g, ' ')  // Normalize whitespace
      .replace(/\d+ hours? ago|\d+ minutes? ago/g, '')  // Remove relative timestamps
      .trim()
      .toLowerCase();
    
    return crypto.createHash('sha256').update(normalized).digest('hex');
  }

  normalizeText(text) {
    if (!text) return '';
    
    return text
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
  }

  createSecondaryFingerprint(data) {
    const secondaryData = `${data.video_id || ''}|${data.tags.join(',')}|${data.normalized_url}`;
    return crypto.createHash('md5').update(secondaryData).digest('hex');
  }

  getCurrentProcessingVersion() {
    // Version based on your config files - increment when you tune models
    return '2.0.0'; // Update this when you retune your models
  }

  hasNewerProcessingVersion(oldVersion) {
    return oldVersion < this.getCurrentProcessingVersion();
  }

  hasPriorityTagsNeedingReprocessing(processedInfo) {
    // Check if content has priority tags but wasn't processed with priority models
    const priorityTags = ['bitcoin', 'tesla', 'solana', 'sbr'];
    const contentTags = processedInfo.content_metadata?.tags || [];
    
    const hasPriorityTags = priorityTags.some(tag => 
      contentTags.some(contentTag => contentTag.includes(tag))
    );
    
    return hasPriorityTags && processedInfo.processing_version < '2.0.0';
  }

  // Database operations (implement based on your database choice)
  async loadProcessedContent() {
    // Load recent processed content into memory cache
    this.logger.info('Loading processed content cache...');
  }

  async checkDatabase(fingerprint) {
    // Check if content exists in database
    return { found: false };
  }

  async saveToDatabase(processingInfo) {
    // Save processing info to database
    this.logger.info(`Saving processing info for: ${processingInfo.content_hash.substring(0, 8)}...`);
  }

  async findContentByIdentifier(identifier) {
    // Find content hashes by URL, post_id, etc.
    return [];
  }
}

module.exports = { DuplicateDetectionManager };
