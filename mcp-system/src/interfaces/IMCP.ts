import { IMCPCommand, IMCPCommandContext, IMCPCommandParams, IMCPCommandResult } from './IMCPCommand';
import { IMCPModule, IMCPModuleInitOptions } from './IMCPModule';
import { IMCPPlugin, IMCPPluginInitOptions } from './IMCPPlugin';

/**
 * Interface for MCP system configuration
 */
export interface IMCPConfig {
  logLevel: string;
  logDirectory: string;
  configDirectory: string;
  modulesDirectory: string;
  pluginsDirectory: string;
  securityEnabled: boolean;
  defaultPermissions: string[];
  [key: string]: any;
}

/**
 * Interface for MCP system initialization options
 */
export interface IMCPInitOptions {
  configPath?: string;
  logLevel?: string;
  disableSecurity?: boolean;
  [key: string]: any;
}

/**
 * Interface for MCP system implementation
 */
export interface IMCP {
  modules: Map<string, IMCPModule>;
  plugins: Map<string, IMCPPlugin>;
  config: IMCPConfig;
  
  /**
   * Initialize the MCP system
   * @param options Initialization options
   */
  initialize(options?: IMCPInitOptions): Promise<boolean>;
  
  /**
   * Execute a command
   * @param commandString Full command string (e.g., "fs.readFile path=/tmp/file.txt")
   * @param context Command execution context
   */
  executeCommand(commandString: string, context: IMCPCommandContext): Promise<IMCPCommandResult>;
  
  /**
   * Execute a command with explicit module, command, and parameters
   * @param moduleName Name of the module
   * @param commandName Name of the command
   * @param params Command parameters
   * @param context Command execution context
   */
  executeCommandExplicit(
    moduleName: string,
    commandName: string,
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult>;
  
  /**
   * Load a module
   * @param modulePath Path to the module
   * @param options Module initialization options
   */
  loadModule(modulePath: string, options?: IMCPModuleInitOptions): Promise<IMCPModule>;
  
  /**
   * Unload a module
   * @param moduleName Name of the module to unload
   */
  unloadModule(moduleName: string): Promise<boolean>;
  
  /**
   * Load a plugin
   * @param pluginPath Path to the plugin
   * @param options Plugin initialization options
   */
  loadPlugin(pluginPath: string, options?: IMCPPluginInitOptions): Promise<IMCPPlugin>;
  
  /**
   * Unload a plugin
   * @param pluginName Name of the plugin to unload
   */
  unloadPlugin(pluginName: string): Promise<boolean>;
  
  /**
   * Get a command by module and command name
   * @param moduleName Name of the module
   * @param commandName Name of the command
   */
  getCommand(moduleName: string, commandName: string): IMCPCommand | undefined;
  
  /**
   * Emit an event to all plugins
   * @param eventName Name of the event
   * @param eventData Data associated with the event
   */
  emitEvent(eventName: string, eventData: any): Promise<void>;
  
  /**
   * Shutdown the MCP system
   */
  shutdown(): Promise<void>;
} 