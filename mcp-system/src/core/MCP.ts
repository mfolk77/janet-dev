import fs from 'fs-extra';
import path from 'path';
import { IMCP, IMCPConfig, IMCPInitOptions } from '../interfaces/IMCP';
import { IMCPCommand, IMCPCommandContext, IMCPCommandParams, IMCPCommandResult } from '../interfaces/IMCPCommand';
import { IMCPModule, IMCPModuleInitOptions } from '../interfaces/IMCPModule';
import { IMCPPlugin, IMCPPluginInitOptions } from '../interfaces/IMCPPlugin';
import logger, { createLogger } from '../utils/logger';
import { SecurityManager } from '../security/SecurityManager';

/**
 * Default MCP configuration
 */
const DEFAULT_CONFIG: IMCPConfig = {
  logLevel: 'info',
  logDirectory: path.join(process.cwd(), 'logs'),
  configDirectory: path.join(process.cwd(), 'config'),
  modulesDirectory: path.join(process.cwd(), 'src', 'modules'),
  pluginsDirectory: path.join(process.cwd(), 'src', 'plugins'),
  securityEnabled: true,
  defaultPermissions: ['system.read'],
};

/**
 * Main MCP system implementation
 */
export class MCP implements IMCP {
  public modules: Map<string, IMCPModule> = new Map();
  public plugins: Map<string, IMCPPlugin> = new Map();
  public config: IMCPConfig;
  private securityManager?: SecurityManager;
  private initialized: boolean = false;
  
  /**
   * Create a new MCP instance
   * @param config MCP configuration
   */
  constructor(config: Partial<IMCPConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }
  
  /**
   * Initialize the MCP system
   * @param options Initialization options
   */
  public async initialize(options: IMCPInitOptions = {}): Promise<boolean> {
    if (this.initialized) {
      logger.warn('MCP is already initialized');
      return true;
    }
    
    try {
      // Override config with options
      if (options.logLevel) {
        this.config.logLevel = options.logLevel;
      }
      
      if (options.disableSecurity !== undefined) {
        this.config.securityEnabled = !options.disableSecurity;
      }
      
      // Initialize logger
      const customLogger = createLogger({
        logLevel: this.config.logLevel,
        logDirectory: this.config.logDirectory,
      });
      
      // Replace the default logger with our custom one
      Object.assign(logger, customLogger);
      
      logger.info('Initializing MCP system');
      
      // Ensure directories exist
      await fs.ensureDir(this.config.logDirectory);
      await fs.ensureDir(this.config.configDirectory);
      
      // Initialize security manager if security is enabled
      if (this.config.securityEnabled) {
        logger.info('Initializing security manager');
        
        // Load or create security config
        const securityConfigPath = path.join(this.config.configDirectory, 'security.json');
        let securityConfig: any = {};
        
        if (await fs.pathExists(securityConfigPath)) {
          securityConfig = await fs.readJSON(securityConfigPath);
        } else {
          // Create default security config
          securityConfig = {
            usersFilePath: path.join(this.config.configDirectory, 'users.json'),
            tokenSecret: Math.random().toString(36).substring(2, 15),
            tokenExpiration: 86400, // 24 hours
            encryptionKey: Math.random().toString(36).substring(2, 15),
          };
          
          // Save default security config
          await fs.writeJSON(securityConfigPath, securityConfig, { spaces: 2 });
        }
        
        // Create security manager
        this.securityManager = new SecurityManager(securityConfig);
        await this.securityManager.initialize();
      }
      
      // Load built-in modules
      await this.loadBuiltInModules();
      
      this.initialized = true;
      logger.info('MCP system initialized successfully');
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize MCP system', { error });
      return false;
    }
  }
  
  /**
   * Load built-in modules
   */
  private async loadBuiltInModules(): Promise<void> {
    logger.info('Loading built-in modules');
    
    // Get all module directories
    const modulesDirExists = await fs.pathExists(this.config.modulesDirectory);
    if (!modulesDirExists) {
      logger.warn(`Modules directory ${this.config.modulesDirectory} does not exist`);
      return;
    }
    
    const moduleDirs = await fs.readdir(this.config.modulesDirectory);
    
    // Load each module
    for (const moduleDir of moduleDirs) {
      const modulePath = path.join(this.config.modulesDirectory, moduleDir);
      const stats = await fs.stat(modulePath);
      
      if (stats.isDirectory()) {
        try {
          await this.loadModule(modulePath);
        } catch (error) {
          logger.error(`Failed to load module ${moduleDir}`, { error });
        }
      }
    }
    
    logger.info(`Loaded ${this.modules.size} built-in modules`);
  }
  
  /**
   * Execute a command
   * @param commandString Full command string (e.g., "fs.readFile path=/tmp/file.txt")
   * @param context Command execution context
   */
  public async executeCommand(
    commandString: string,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    if (!this.initialized) {
      return {
        success: false,
        error: 'MCP is not initialized',
        timestamp: Date.now(),
      };
    }
    
    // Parse command string
    const parts = commandString.trim().split(' ');
    const [moduleAndCommand, ...paramParts] = parts;
    
    if (!moduleAndCommand) {
      return {
        success: false,
        error: 'Invalid command format',
        timestamp: Date.now(),
      };
    }
    
    // Split module and command
    const [moduleName, commandName] = moduleAndCommand.split('.');
    
    if (!moduleName || !commandName) {
      return {
        success: false,
        error: 'Invalid command format. Expected format: module.command param1=value1 param2=value2',
        timestamp: Date.now(),
      };
    }
    
    // Parse parameters
    const params: IMCPCommandParams = {};
    
    for (const paramPart of paramParts) {
      const [key, ...valueParts] = paramPart.split('=');
      const value = valueParts.join('=');
      
      if (key && value !== undefined) {
        // Try to parse as JSON if possible
        try {
          params[key] = JSON.parse(value);
        } catch {
          params[key] = value;
        }
      }
    }
    
    // Execute command
    return this.executeCommandExplicit(moduleName, commandName, params, context);
  }
  
  /**
   * Execute a command with explicit module, command, and parameters
   * @param moduleName Name of the module
   * @param commandName Name of the command
   * @param params Command parameters
   * @param context Command execution context
   */
  public async executeCommandExplicit(
    moduleName: string,
    commandName: string,
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    if (!this.initialized) {
      return {
        success: false,
        error: 'MCP is not initialized',
        timestamp: Date.now(),
      };
    }
    
    // Get module
    const module = this.modules.get(moduleName);
    
    if (!module) {
      return {
        success: false,
        error: `Module ${moduleName} not found`,
        timestamp: Date.now(),
      };
    }
    
    // Get command
    const command = module.getCommand(commandName);
    
    if (!command) {
      return {
        success: false,
        error: `Command ${commandName} not found in module ${moduleName}`,
        timestamp: Date.now(),
      };
    }
    
    // Check authentication if required
    if (command.meta.requiresAuth && this.config.securityEnabled && this.securityManager) {
      if (!context.securityContext.isAuthenticated) {
        return {
          success: false,
          error: `Command ${moduleName}.${commandName} requires authentication`,
          timestamp: Date.now(),
        };
      }
      
      // Check if the user has the required permissions
      if (context.userId && command.meta.permissions && command.meta.permissions.length > 0) {
        const hasPermission = command.meta.permissions.every((permission) => {
          const [category, level] = permission.split('.');
          return this.securityManager!.hasPermission(
            context.userId!,
            category,
            parseInt(level, 10)
          );
        });
        
        if (!hasPermission) {
          return {
            success: false,
            error: `Insufficient permissions to execute command ${moduleName}.${commandName}`,
            timestamp: Date.now(),
          };
        }
      }
    }
    
    // Execute command
    return module.executeCommand(commandName, params, context);
  }
  
  /**
   * Load a module
   * @param modulePath Path to the module
   * @param options Module initialization options
   */
  public async loadModule(
    modulePath: string,
    options?: IMCPModuleInitOptions
  ): Promise<IMCPModule> {
    const moduleName = path.basename(modulePath);
    
    logger.info(`Loading module ${moduleName} from ${modulePath}`);
    
    try {
      // Check if module exists
      const moduleExists = await fs.pathExists(modulePath);
      
      if (!moduleExists) {
        throw new Error(`Module path ${modulePath} does not exist`);
      }
      
      // Check if module is already loaded
      if (this.modules.has(moduleName)) {
        logger.warn(`Module ${moduleName} is already loaded`);
        return this.modules.get(moduleName)!;
      }
      
      // In development, we'll dynamically import the TypeScript modules
      // This is a simplified version for testing purposes
      let ModuleClass;
      
      switch (moduleName) {
        case 'fs':
          ModuleClass = require('../modules/fs').default;
          break;
        case 'terminal':
          ModuleClass = require('../modules/terminal').default;
          break;
        case 'web':
          ModuleClass = require('../modules/web').default;
          break;
        case 'ai':
          ModuleClass = require('../modules/ai').default;
          break;
        default:
          throw new Error(`Unknown module: ${moduleName}`);
      }
      
      // Create module instance
      const module = new ModuleClass();
      
      // Initialize module
      await module.initialize(options);
      
      // Register module
      this.modules.set(moduleName, module);
      
      logger.info(`Module ${moduleName} loaded successfully`);
      
      return module;
    } catch (error) {
      logger.error(`Failed to load module ${moduleName}`, { error });
      throw error;
    }
  }
  
  /**
   * Unload a module
   * @param moduleName Name of the module to unload
   */
  public async unloadModule(moduleName: string): Promise<boolean> {
    logger.info(`Unloading module ${moduleName}`);
    
    // Check if module is loaded
    if (!this.modules.has(moduleName)) {
      logger.warn(`Module ${moduleName} is not loaded`);
      return false;
    }
    
    try {
      // Get module
      const module = this.modules.get(moduleName)!;
      
      // Shutdown module
      await module.shutdown();
      
      // Unregister module
      this.modules.delete(moduleName);
      
      logger.info(`Module ${moduleName} unloaded successfully`);
      
      return true;
    } catch (error) {
      logger.error(`Failed to unload module ${moduleName}`, { error });
      return false;
    }
  }
  
  /**
   * Load a plugin
   * @param pluginPath Path to the plugin
   * @param options Plugin initialization options
   */
  public async loadPlugin(
    pluginPath: string,
    options?: IMCPPluginInitOptions
  ): Promise<IMCPPlugin> {
    const pluginName = path.basename(pluginPath);
    
    logger.info(`Loading plugin ${pluginName} from ${pluginPath}`);
    
    try {
      // Check if plugin exists
      const pluginExists = await fs.pathExists(pluginPath);
      
      if (!pluginExists) {
        throw new Error(`Plugin path ${pluginPath} does not exist`);
      }
      
      // Check if plugin is already loaded
      if (this.plugins.has(pluginName)) {
        logger.warn(`Plugin ${pluginName} is already loaded`);
        return this.plugins.get(pluginName)!;
      }
      
      // In development, we'll dynamically import the TypeScript plugins
      // This is a simplified version for testing purposes
      // For now, we don't have any plugins, so we'll just throw an error
      throw new Error(`No plugins are currently implemented`);
      
      // Initialize plugin
      // await plugin.initialize(options || {}, this.modules);
      
      // Register plugin
      // this.plugins.set(pluginName, plugin);
      
      // Register modules provided by the plugin
      // const providedModules = plugin.getProvidedModules();
      
      // for (const module of providedModules) {
      //   this.modules.set(module.meta.name, module);
      //   logger.info(`Registered module ${module.meta.name} provided by plugin ${pluginName}`);
      // }
      
      // logger.info(`Plugin ${pluginName} loaded successfully`);
      
      // return plugin;
    } catch (error) {
      logger.error(`Failed to load plugin ${pluginName}`, { error });
      throw error;
    }
  }
  
  /**
   * Unload a plugin
   * @param pluginName Name of the plugin to unload
   */
  public async unloadPlugin(pluginName: string): Promise<boolean> {
    logger.info(`Unloading plugin ${pluginName}`);
    
    // Check if plugin is loaded
    if (!this.plugins.has(pluginName)) {
      logger.warn(`Plugin ${pluginName} is not loaded`);
      return false;
    }
    
    try {
      // Get plugin
      const plugin = this.plugins.get(pluginName)!;
      
      // Unload plugin
      await plugin.unload();
      
      // Unregister modules provided by the plugin
      const providedModules = plugin.getProvidedModules();
      
      for (const module of providedModules) {
        this.modules.delete(module.meta.name);
        logger.info(`Unregistered module ${module.meta.name} provided by plugin ${pluginName}`);
      }
      
      // Unregister plugin
      this.plugins.delete(pluginName);
      
      logger.info(`Plugin ${pluginName} unloaded successfully`);
      
      return true;
    } catch (error) {
      logger.error(`Failed to unload plugin ${pluginName}`, { error });
      return false;
    }
  }
  
  /**
   * Get a command by module and command name
   * @param moduleName Name of the module
   * @param commandName Name of the command
   */
  public getCommand(
    moduleName: string,
    commandName: string
  ): IMCPCommand | undefined {
    const module = this.modules.get(moduleName);
    
    if (!module) {
      return undefined;
    }
    
    return module.getCommand(commandName);
  }
  
  /**
   * Emit an event to all plugins
   * @param eventName Name of the event
   * @param eventData Data associated with the event
   */
  public async emitEvent(eventName: string, eventData: any): Promise<void> {
    logger.debug(`Emitting event ${eventName}`, { eventData });
    
    // Notify all plugins
    for (const [pluginName, plugin] of this.plugins.entries()) {
      try {
        await plugin.handleEvent(eventName, eventData);
      } catch (error) {
        logger.error(`Error handling event ${eventName} in plugin ${pluginName}`, { error });
      }
    }
  }
  
  /**
   * Shutdown the MCP system
   */
  public async shutdown(): Promise<void> {
    if (!this.initialized) {
      logger.warn('MCP is not initialized');
      return;
    }
    
    logger.info('Shutting down MCP system');
    
    // Unload all plugins
    for (const pluginName of this.plugins.keys()) {
      await this.unloadPlugin(pluginName);
    }
    
    // Unload all modules
    for (const moduleName of this.modules.keys()) {
      await this.unloadModule(moduleName);
    }
    
    this.initialized = false;
    
    logger.info('MCP system shut down successfully');
  }
} 