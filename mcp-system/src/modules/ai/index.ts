import { BaseModule } from '../../core/BaseModule';
import { IMCPModuleMeta, IMCPModuleInitOptions } from '../../interfaces/IMCPModule';
import logger from '../../utils/logger';
import { ClaudeApiCommand } from './commands/ClaudeApiCommand';

/**
 * AI module metadata
 */
const AI_MODULE_META: IMCPModuleMeta = {
  name: 'ai',
  description: 'AI model integration',
  version: '1.0.0',
  author: 'MCP System',
  dependencies: [],
};

/**
 * AI module for MCP
 */
export default class AIModule extends BaseModule {
  /**
   * Create a new AI module
   */
  constructor() {
    super(AI_MODULE_META);
  }
  
  /**
   * Initialize the AI module
   * @param options Initialization options
   */
  protected async onInitialize(options?: IMCPModuleInitOptions): Promise<boolean> {
    try {
      logger.info('Initializing AI module');
      
      // Register commands
      this.registerCommand(new ClaudeApiCommand());
      
      logger.info(`Registered ${this.commands.size} AI commands`);
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize AI module', { error });
      return false;
    }
  }
  
  /**
   * Shutdown the AI module
   */
  protected async onShutdown(): Promise<void> {
    logger.info('Shutting down AI module');
  }
} 