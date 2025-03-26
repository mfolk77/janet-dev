import { BaseModule } from '../../core/BaseModule';
import { IMCPModuleMeta, IMCPModuleInitOptions } from '../../interfaces/IMCPModule';
import logger from '../../utils/logger';
import { ExecuteCommandCommand } from './commands/ExecuteCommandCommand';

/**
 * Terminal module metadata
 */
const TERMINAL_MODULE_META: IMCPModuleMeta = {
  name: 'terminal',
  description: 'Terminal command execution',
  version: '1.0.0',
  author: 'MCP System',
  dependencies: [],
};

/**
 * Terminal module for MCP
 */
export default class TerminalModule extends BaseModule {
  /**
   * Create a new terminal module
   */
  constructor() {
    super(TERMINAL_MODULE_META);
  }
  
  /**
   * Initialize the terminal module
   * @param options Initialization options
   */
  protected async onInitialize(options?: IMCPModuleInitOptions): Promise<boolean> {
    try {
      logger.info('Initializing terminal module');
      
      // Register commands
      this.registerCommand(new ExecuteCommandCommand());
      
      logger.info(`Registered ${this.commands.size} terminal commands`);
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize terminal module', { error });
      return false;
    }
  }
  
  /**
   * Shutdown the terminal module
   */
  protected async onShutdown(): Promise<void> {
    logger.info('Shutting down terminal module');
  }
} 