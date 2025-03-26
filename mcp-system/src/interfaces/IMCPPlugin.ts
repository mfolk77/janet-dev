import { IMCPModule } from './IMCPModule';

/**
 * Interface for MCP plugin metadata
 */
export interface IMCPPluginMeta {
  name: string;
  description: string;
  version: string;
  author: string;
  dependencies?: string[];
}

/**
 * Interface for MCP plugin initialization options
 */
export interface IMCPPluginInitOptions {
  configPath?: string;
  logLevel?: string;
  [key: string]: any;
}

/**
 * Interface for MCP plugin implementation
 */
export interface IMCPPlugin {
  meta: IMCPPluginMeta;
  
  /**
   * Initialize the plugin
   * @param options Initialization options
   * @param modules Available modules that the plugin can interact with
   */
  initialize(options: IMCPPluginInitOptions, modules: Map<string, IMCPModule>): Promise<boolean>;
  
  /**
   * Called when the plugin is being unloaded
   */
  unload(): Promise<void>;
  
  /**
   * Get the modules that this plugin provides
   */
  getProvidedModules(): IMCPModule[];
  
  /**
   * Handle events from the MCP system
   * @param eventName Name of the event
   * @param eventData Data associated with the event
   */
  handleEvent(eventName: string, eventData: any): Promise<void>;
} 