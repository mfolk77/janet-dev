import { IMCPCommand, IMCPCommandContext, IMCPCommandParams, IMCPCommandResult } from '../interfaces/IMCPCommand';
import { IMCPModule, IMCPModuleMeta, IMCPModuleInitOptions } from '../interfaces/IMCPModule';
import logger from '../utils/logger';

/**
 * Base implementation of an MCP module
 */
export abstract class BaseModule implements IMCPModule {
  public meta: IMCPModuleMeta;
  public commands: Map<string, IMCPCommand> = new Map();
  protected initialized: boolean = false;
  
  /**
   * Create a new module
   * @param meta Module metadata
   */
  constructor(meta: IMCPModuleMeta) {
    this.meta = meta;
  }
  
  /**
   * Initialize the module
   * @param options Initialization options
   */
  public async initialize(options?: IMCPModuleInitOptions): Promise<boolean> {
    if (this.initialized) {
      logger.warn(`Module ${this.meta.name} is already initialized`);
      return true;
    }
    
    try {
      // Call the module-specific initialization
      const success = await this.onInitialize(options);
      
      if (success) {
        this.initialized = true;
        logger.info(`Module ${this.meta.name} initialized successfully`);
      } else {
        logger.error(`Failed to initialize module ${this.meta.name}`);
      }
      
      return success;
    } catch (error) {
      logger.error(`Error initializing module ${this.meta.name}`, { error });
      return false;
    }
  }
  
  /**
   * Module-specific initialization
   * @param options Initialization options
   */
  protected abstract onInitialize(options?: IMCPModuleInitOptions): Promise<boolean>;
  
  /**
   * Get a command by name
   * @param commandName Name of the command
   */
  public getCommand(commandName: string): IMCPCommand | undefined {
    return this.commands.get(commandName);
  }
  
  /**
   * Register a new command
   * @param command Command to register
   */
  public registerCommand(command: IMCPCommand): void {
    if (this.commands.has(command.meta.name)) {
      logger.warn(`Command ${command.meta.name} is already registered in module ${this.meta.name}`);
      return;
    }
    
    this.commands.set(command.meta.name, command);
    logger.debug(`Registered command ${command.meta.name} in module ${this.meta.name}`);
  }
  
  /**
   * Unregister a command
   * @param commandName Name of the command to unregister
   */
  public unregisterCommand(commandName: string): boolean {
    if (!this.commands.has(commandName)) {
      logger.warn(`Command ${commandName} is not registered in module ${this.meta.name}`);
      return false;
    }
    
    this.commands.delete(commandName);
    logger.debug(`Unregistered command ${commandName} from module ${this.meta.name}`);
    return true;
  }
  
  /**
   * Execute a command
   * @param commandName Name of the command
   * @param params Command parameters
   * @param context Command execution context
   */
  public async executeCommand(
    commandName: string,
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    const command = this.getCommand(commandName);
    
    if (!command) {
      return {
        success: false,
        error: `Command ${commandName} not found in module ${this.meta.name}`,
        timestamp: Date.now(),
      };
    }
    
    // Validate parameters if the command has a validate method
    if (command.validate && !command.validate(params)) {
      return {
        success: false,
        error: `Invalid parameters for command ${commandName}`,
        timestamp: Date.now(),
      };
    }
    
    // Execute the command
    const startTime = Date.now();
    try {
      const result = await command.execute(params, context);
      const executionTime = Date.now() - startTime;
      
      // Add execution time to the result
      return {
        ...result,
        executionTime,
      };
    } catch (error) {
      logger.error(`Error executing command ${commandName}`, { error });
      return {
        success: false,
        error: `Error executing command ${commandName}: ${error instanceof Error ? error.message : String(error)}`,
        timestamp: Date.now(),
        executionTime: Date.now() - startTime,
      };
    }
  }
  
  /**
   * Shutdown the module
   */
  public async shutdown(): Promise<void> {
    if (!this.initialized) {
      logger.warn(`Module ${this.meta.name} is not initialized`);
      return;
    }
    
    try {
      // Call the module-specific shutdown
      await this.onShutdown();
      
      this.initialized = false;
      logger.info(`Module ${this.meta.name} shut down successfully`);
    } catch (error) {
      logger.error(`Error shutting down module ${this.meta.name}`, { error });
    }
  }
  
  /**
   * Module-specific shutdown
   */
  protected abstract onShutdown(): Promise<void>;
} 