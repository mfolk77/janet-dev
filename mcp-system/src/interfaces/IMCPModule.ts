import { IMCPCommand, IMCPCommandContext, IMCPCommandParams, IMCPCommandResult } from './IMCPCommand';

/**
 * Interface for MCP module metadata
 */
export interface IMCPModuleMeta {
  name: string;
  description: string;
  version: string;
  author: string;
  dependencies?: string[];
}

/**
 * Interface for MCP module initialization options
 */
export interface IMCPModuleInitOptions {
  configPath?: string;
  logLevel?: string;
  [key: string]: any;
}

/**
 * Interface for MCP module implementation
 */
export interface IMCPModule {
  meta: IMCPModuleMeta;
  commands: Map<string, IMCPCommand>;
  
  /**
   * Initialize the module
   * @param options Initialization options
   */
  initialize(options?: IMCPModuleInitOptions): Promise<boolean>;
  
  /**
   * Get a command by name
   * @param commandName Name of the command
   */
  getCommand(commandName: string): IMCPCommand | undefined;
  
  /**
   * Register a new command
   * @param command Command to register
   */
  registerCommand(command: IMCPCommand): void;
  
  /**
   * Unregister a command
   * @param commandName Name of the command to unregister
   */
  unregisterCommand(commandName: string): boolean;
  
  /**
   * Execute a command
   * @param commandName Name of the command
   * @param params Command parameters
   * @param context Command execution context
   */
  executeCommand(
    commandName: string,
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult>;
  
  /**
   * Shutdown the module
   */
  shutdown(): Promise<void>;
} 