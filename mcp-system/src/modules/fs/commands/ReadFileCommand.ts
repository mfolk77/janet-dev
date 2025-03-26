import fs from 'fs-extra';
import path from 'path';
import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import logger from '../../../utils/logger';

/**
 * Command metadata
 */
const READ_FILE_COMMAND_META: IMCPCommandMeta = {
  name: 'readFile',
  description: 'Read the contents of a file',
  category: 'file',
  requiresAuth: false,
  permissions: ['fs.read'],
};

/**
 * Command to read a file
 */
export class ReadFileCommand extends BaseCommand {
  /**
   * Create a new read file command
   */
  constructor() {
    super(READ_FILE_COMMAND_META);
  }
  
  /**
   * Validate command parameters
   * @param params Command parameters
   */
  public validate(params: IMCPCommandParams): boolean {
    return typeof params.path === 'string' && params.path.length > 0;
  }
  
  /**
   * Execute the command
   * @param params Command parameters
   * @param context Command execution context
   */
  protected async onExecute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    try {
      const filePath = this.resolvePath(params.path as string, context.workingDirectory);
      
      // Check if file exists
      if (!await fs.pathExists(filePath)) {
        return {
          success: false,
          error: `File ${filePath} does not exist`,
          timestamp: Date.now(),
        };
      }
      
      // Get file stats
      const stats = await fs.stat(filePath);
      
      // Check if it's a file
      if (!stats.isFile()) {
        return {
          success: false,
          error: `${filePath} is not a file`,
          timestamp: Date.now(),
        };
      }
      
      // Read file
      const encoding = params.encoding as BufferEncoding || 'utf8';
      const content = await fs.readFile(filePath, { encoding });
      
      // Get file info
      const fileInfo = {
        path: filePath,
        size: stats.size,
        created: stats.birthtime,
        modified: stats.mtime,
        accessed: stats.atime,
        isDirectory: stats.isDirectory(),
        isFile: stats.isFile(),
        isSymbolicLink: stats.isSymbolicLink(),
      };
      
      return {
        success: true,
        data: {
          content,
          fileInfo,
        },
        timestamp: Date.now(),
      };
    } catch (error) {
      logger.error('Error reading file', { error, params });
      
      return {
        success: false,
        error: `Error reading file: ${error instanceof Error ? error.message : String(error)}`,
        timestamp: Date.now(),
      };
    }
  }
  
  /**
   * Resolve a path relative to the working directory
   * @param filePath File path
   * @param workingDirectory Working directory
   */
  private resolvePath(filePath: string, workingDirectory: string): string {
    if (path.isAbsolute(filePath)) {
      return filePath;
    }
    
    return path.resolve(workingDirectory, filePath);
  }
} 