import axios from 'axios';
import fs from 'fs-extra';
import path from 'path';
import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import logger from '../../../utils/logger';

/**
 * Command metadata
 */
const CLAUDE_API_COMMAND_META: IMCPCommandMeta = {
  name: 'claude',
  description: 'Make a request to the Claude API',
  category: 'ai',
  requiresAuth: true,
  permissions: ['ai.claude'],
};

/**
 * Claude API models
 */
enum ClaudeModel {
  CLAUDE_3_OPUS = 'claude-3-opus-20240229',
  CLAUDE_3_SONNET = 'claude-3-sonnet-20240229',
  CLAUDE_3_HAIKU = 'claude-3-haiku-20240307',
  CLAUDE_2_1 = 'claude-2.1',
  CLAUDE_2_0 = 'claude-2.0',
  CLAUDE_INSTANT_1_2 = 'claude-instant-1.2',
}

/**
 * Command to make a request to the Claude API
 */
export class ClaudeApiCommand extends BaseCommand {
  private apiKey: string | null = null;
  
  /**
   * Create a new Claude API command
   */
  constructor() {
    super(CLAUDE_API_COMMAND_META);
  }
  
  /**
   * Validate command parameters
   * @param params Command parameters
   */
  public validate(params: IMCPCommandParams): boolean {
    return (
      typeof params.prompt === 'string' && 
      params.prompt.length > 0 &&
      (!params.model || typeof params.model === 'string')
    );
  }
  
  /**
   * Execute the command
   * @param params Command parameters
   * @param context Command execution context
   */
  protected async onExecute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    try {
      // Get API key
      const apiKey = await this.getApiKey(params.apiKey as string);
      
      if (!apiKey) {
        return {
          success: false,
          error: 'Claude API key not found. Please provide an API key.',
          timestamp: Date.now(),
        };
      }
      
      // Get parameters
      const prompt = params.prompt as string;
      const model = params.model as string || ClaudeModel.CLAUDE_3_HAIKU;
      const maxTokens = params.maxTokens as number || 1000;
      const temperature = params.temperature as number || 0.7;
      const system = params.system as string || '';
      
      logger.info(`Making Claude API request with model ${model}`, {
        userId: context.userId,
        sessionId: context.sessionId,
      });
      
      // Prepare request
      const requestBody: any = {
        model,
        max_tokens: maxTokens,
        temperature,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
      };
      
      // Add system prompt if provided
      if (system) {
        requestBody.system = system;
      }
      
      // Make request
      const response = await axios.post('https://api.anthropic.com/v1/messages', requestBody, {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
      });
      
      // Log response
      logger.debug('Claude API response received', {
        model,
        userId: context.userId,
        sessionId: context.sessionId,
      });
      
      return {
        success: true,
        data: {
          response: response.data,
          content: response.data.content[0].text,
          model: response.data.model,
          usage: response.data.usage,
        },
        timestamp: Date.now(),
      };
    } catch (error) {
      logger.error('Error making Claude API request', { error, params });
      
      return {
        success: false,
        error: `Error making Claude API request: ${error instanceof Error ? error.message : String(error)}`,
        timestamp: Date.now(),
      };
    }
  }
  
  /**
   * Get the Claude API key
   * @param providedApiKey API key provided in the command
   */
  private async getApiKey(providedApiKey?: string): Promise<string | null> {
    // Use provided API key if available
    if (providedApiKey) {
      this.apiKey = providedApiKey;
      return providedApiKey;
    }
    
    // Use cached API key if available
    if (this.apiKey) {
      return this.apiKey;
    }
    
    // Try to get API key from environment variable
    if (process.env.CLAUDE_API_KEY) {
      this.apiKey = process.env.CLAUDE_API_KEY;
      return this.apiKey;
    }
    
    // Try to get API key from config file
    try {
      const configPath = path.join(process.cwd(), 'config', 'claude.json');
      
      if (await fs.pathExists(configPath)) {
        const config = await fs.readJSON(configPath);
        
        if (config.apiKey) {
          this.apiKey = config.apiKey;
          return this.apiKey;
        }
      }
    } catch (error) {
      logger.error('Error reading Claude API key from config file', { error });
    }
    
    return null;
  }
} 