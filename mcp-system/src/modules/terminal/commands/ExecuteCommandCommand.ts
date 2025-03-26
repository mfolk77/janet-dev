import { spawn } from 'child_process';
import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import logger from '../../../utils/logger';

/**
 * Command metadata
 */
const EXECUTE_COMMAND_META: IMCPCommandMeta = {
  name: 'execute',
  description: 'Execute a shell command',
  category: 'terminal',
  requiresAuth: false,
  permissions: ['terminal.execute'],
};

/**
 * Command to execute a shell command
 */
export class ExecuteCommandCommand extends BaseCommand {
  /**
   * Create a new execute command
   */
  constructor() {
    super(EXECUTE_COMMAND_META);
  }
  
  /**
   * Validate command parameters
   * @param params Command parameters
   */
  public validate(params: IMCPCommandParams): boolean {
    return typeof params.command === 'string' && params.command.length > 0;
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
      const command = params.command as string;
      const shell = params.shell as string || '/bin/bash';
      const timeout = params.timeout as number || 30000; // 30 seconds
      const cwd = params.cwd as string || context.workingDirectory;
      
      logger.info(`Executing command: ${command}`, {
        shell,
        cwd,
        timeout,
        userId: context.userId,
        sessionId: context.sessionId,
      });
      
      // Execute command
      const result = await this.executeCommand(command, {
        shell,
        cwd,
        timeout,
        env: context.environmentVars,
      });
      
      return {
        success: result.exitCode === 0,
        data: {
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.exitCode,
        },
        timestamp: Date.now(),
      };
    } catch (error) {
      logger.error('Error executing command', { error, params });
      
      return {
        success: false,
        error: `Error executing command: ${error instanceof Error ? error.message : String(error)}`,
        timestamp: Date.now(),
      };
    }
  }
  
  /**
   * Execute a shell command
   * @param command Command to execute
   * @param options Command options
   */
  private executeCommand(
    command: string,
    options: {
      shell: string;
      cwd: string;
      timeout: number;
      env: Record<string, string>;
    }
  ): Promise<{ stdout: string; stderr: string; exitCode: number }> {
    return new Promise((resolve, reject) => {
      // Spawn process with shell=false for security
      const childProcess = spawn(options.shell, ['-c', command], {
        cwd: options.cwd,
        env: { ...process.env, ...options.env },
        shell: false,
      });
      
      let stdout = '';
      let stderr = '';
      
      // Set timeout
      const timeoutId = setTimeout(() => {
        childProcess.kill();
        reject(new Error(`Command timed out after ${options.timeout}ms`));
      }, options.timeout);
      
      // Collect stdout
      childProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });
      
      // Collect stderr
      childProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      // Handle process exit
      childProcess.on('close', (exitCode) => {
        clearTimeout(timeoutId);
        resolve({ stdout, stderr, exitCode: exitCode || 0 });
      });
      
      // Handle process error
      childProcess.on('error', (error) => {
        clearTimeout(timeoutId);
        reject(error);
      });
    });
  }
} 