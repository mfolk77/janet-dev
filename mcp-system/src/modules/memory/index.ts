import { BaseModule } from '../../core/BaseModule';
import { IMCPModuleMeta, IMCPModuleInitOptions } from '../../interfaces/IMCPModule';
import logger from '../../utils/logger';
import { StoreMemoryCommand } from './commands/StoreMemoryCommand';
// TODO: Implement these commands
// import { RetrieveMemoryCommand } from './commands/RetrieveMemoryCommand';
// import { SearchMemoryCommand } from './commands/SearchMemoryCommand';
// import { DeleteMemoryCommand } from './commands/DeleteMemoryCommand';
import fs from 'fs-extra';
import path from 'path';

const MEMORY_MODULE_META: IMCPModuleMeta = {
  name: 'memory',
  description: 'Memory management module for storing and retrieving AI memories',
  author: 'MCP System',
  version: '1.0.0',
};

/**
 * Memory module for MCP
 * Handles persistent storage and retrieval of AI memories
 */
export class MemoryModule extends BaseModule {
  private memoryDirectory: string;
  
  constructor() {
    super(MEMORY_MODULE_META);
    
    // Set the memory directory to ~/Library/Application Support/Janet/memory
    this.memoryDirectory = path.join(process.env.HOME || '~', 'Library', 'Application Support', 'Janet', 'memory');
  }
  
  /**
   * Initialize the memory module
   */
  protected async onInitialize(options?: IMCPModuleInitOptions): Promise<boolean> {
    try {
      logger.info('Initializing memory module');
      
      // Ensure the memory directory exists
      await fs.ensureDir(this.memoryDirectory);
      
      // Register commands
      this.registerCommand(new StoreMemoryCommand(this.memoryDirectory));
      // this.registerCommand(new RetrieveMemoryCommand(this.memoryDirectory));
      // this.registerCommand(new SearchMemoryCommand(this.memoryDirectory));
      // this.registerCommand(new DeleteMemoryCommand(this.memoryDirectory));
      
      logger.info('Memory module initialized successfully');
      return true;
    } catch (error) {
      logger.error('Failed to initialize memory module', { error });
      return false;
    }
  }
  
  /**
   * Get the memory directory
   */
  public getMemoryDirectory(): string {
    return this.memoryDirectory;
  }

  /**
   * Shutdown the memory module
   */
  protected async onShutdown(): Promise<void> {
    try {
      logger.info('Shutting down memory module');
      
      // Perform any cleanup tasks here
      
      logger.info('Memory module shut down successfully');
    } catch (error) {
      logger.error('Failed to shut down memory module', { error });
    }
  }
} 