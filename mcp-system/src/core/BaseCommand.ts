import { IMCPCommand, IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../interfaces/IMCPCommand';
import logger from '../utils/logger';

/**
 * Base implementation of an MCP command
 */
export abstract class BaseCommand implements IMCPCommand {
  public meta: IMCPCommandMeta;
  
  /**
   * Create a new command
   * @param meta Command metadata
   */
  constructor(meta: IMCPCommandMeta) {
    this.meta = meta;
  }
  
  /**
   * Execute the command
   * @param params Command parameters
   * @param context Command execution context
   */
  public async execute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    // Log command execution
    logger.debug(`Executing command ${this.meta.name}`, {
      params,
      userId: context.userId,
      sessionId: context.sessionId,
    });
    
    const startTime = Date.now();
    
    try {
      // Validate parameters if the command has a validate method
      if (this.validate && !this.validate(params)) {
        return {
          success: false,
          error: `Invalid parameters for command ${this.meta.name}`,
          timestamp: startTime,
        };
      }
      
      // Execute the command implementation
      const result = await this.onExecute(params, context);
      
      // Log command result
      logger.debug(`Command ${this.meta.name} executed successfully`, {
        executionTime: Date.now() - startTime,
        userId: context.userId,
        sessionId: context.sessionId,
      });
      
      return {
        ...result,
        timestamp: startTime,
        executionTime: Date.now() - startTime,
      };
    } catch (error) {
      // Log command error
      logger.error(`Error executing command ${this.meta.name}`, {
        error,
        params,
        userId: context.userId,
        sessionId: context.sessionId,
      });
      
      return {
        success: false,
        error: `Error executing command ${this.meta.name}: ${error instanceof Error ? error.message : String(error)}`,
        timestamp: startTime,
        executionTime: Date.now() - startTime,
      };
    }
  }
  
  /**
   * Command-specific execution
   * @param params Command parameters
   * @param context Command execution context
   */
  protected abstract onExecute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult>;
  
  /**
   * Validate command parameters
   * @param params Command parameters
   */
  public validate?(params: IMCPCommandParams): boolean;
  
  /**
   * Get command help
   */
  public help(): string {
    return `
Command: ${this.meta.name}
Description: ${this.meta.description}
Category: ${this.meta.category}
Requires Authentication: ${this.meta.requiresAuth ? 'Yes' : 'No'}
Required Permissions: ${this.meta.permissions?.join(', ') || 'None'}
    `.trim();
  }
} 