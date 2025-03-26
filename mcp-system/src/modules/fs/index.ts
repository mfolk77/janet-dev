import { BaseModule } from '../../core/BaseModule';
import { IMCPModuleMeta, IMCPModuleInitOptions } from '../../interfaces/IMCPModule';
import logger from '../../utils/logger';
import { ReadFileCommand } from './commands/ReadFileCommand';

/**
 * File system module metadata
 */
const FS_MODULE_META: IMCPModuleMeta = {
  name: 'fs',
  description: 'File system operations',
  version: '1.0.0',
  author: 'MCP System',
  dependencies: [],
};

/**
 * File system module for MCP
 */
export default class FileSystemModule extends BaseModule {
  /**
   * Create a new file system module
   */
  constructor() {
    super(FS_MODULE_META);
  }
  
  /**
   * Initialize the file system module
   * @param options Initialization options
   */
  protected async onInitialize(options?: IMCPModuleInitOptions): Promise<boolean> {
    try {
      logger.info('Initializing file system module');
      
      // Register commands
      this.registerCommand(new ReadFileCommand());
      
      logger.info(`Registered ${this.commands.size} file system commands`);
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize file system module', { error });
      return false;
    }
  }
  
  /**
   * Shutdown the file system module
   */
  protected async onShutdown(): Promise<void> {
    logger.info('Shutting down file system module');
  }
} 