import { BaseModule } from '../../core/BaseModule';
import { IMCPModuleMeta, IMCPModuleInitOptions } from '../../interfaces/IMCPModule';
import logger from '../../utils/logger';
import { ApiCallCommand } from './commands/ApiCallCommand';

/**
 * Web module metadata
 */
const WEB_MODULE_META: IMCPModuleMeta = {
  name: 'web',
  description: 'Web automation and API integration',
  version: '1.0.0',
  author: 'MCP System',
  dependencies: [],
};

/**
 * Web module for MCP
 */
export default class WebModule extends BaseModule {
  /**
   * Create a new web module
   */
  constructor() {
    super(WEB_MODULE_META);
  }
  
  /**
   * Initialize the web module
   * @param options Initialization options
   */
  protected async onInitialize(options?: IMCPModuleInitOptions): Promise<boolean> {
    try {
      logger.info('Initializing web module');
      
      // Register commands
      this.registerCommand(new ApiCallCommand());
      
      logger.info(`Registered ${this.commands.size} web commands`);
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize web module', { error });
      return false;
    }
  }
  
  /**
   * Shutdown the web module
   */
  protected async onShutdown(): Promise<void> {
    logger.info('Shutting down web module');
  }
} 