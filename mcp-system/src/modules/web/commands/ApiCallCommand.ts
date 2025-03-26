import axios, { AxiosRequestConfig, Method } from 'axios';
import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import logger from '../../../utils/logger';

/**
 * Command metadata
 */
const API_CALL_COMMAND_META: IMCPCommandMeta = {
  name: 'apiCall',
  description: 'Make an API call to a remote service',
  category: 'web',
  requiresAuth: false,
  permissions: ['web.api'],
};

/**
 * Command to make an API call
 */
export class ApiCallCommand extends BaseCommand {
  /**
   * Create a new API call command
   */
  constructor() {
    super(API_CALL_COMMAND_META);
  }
  
  /**
   * Validate command parameters
   * @param params Command parameters
   */
  public validate(params: IMCPCommandParams): boolean {
    return typeof params.url === 'string' && params.url.length > 0;
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
      const url = params.url as string;
      const method = (params.method as string || 'GET').toUpperCase() as Method;
      const headers = params.headers as Record<string, string> || {};
      const data = params.data;
      const timeout = params.timeout as number || 30000; // 30 seconds
      
      logger.info(`Making API call to ${url}`, {
        method,
        userId: context.userId,
        sessionId: context.sessionId,
      });
      
      // Configure request
      const config: AxiosRequestConfig = {
        url,
        method,
        headers,
        timeout,
        validateStatus: () => true, // Don't throw on any status code
      };
      
      // Add data for non-GET requests
      if (method !== 'GET' && data !== undefined) {
        config.data = data;
      }
      
      // Make request
      const response = await axios(config);
      
      // Log response
      logger.debug(`API call response from ${url}`, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
      
      return {
        success: response.status >= 200 && response.status < 300,
        data: {
          status: response.status,
          statusText: response.statusText,
          headers: response.headers,
          data: response.data,
        },
        timestamp: Date.now(),
      };
    } catch (error) {
      logger.error('Error making API call', { error, params });
      
      return {
        success: false,
        error: `Error making API call: ${error instanceof Error ? error.message : String(error)}`,
        timestamp: Date.now(),
      };
    }
  }
} 