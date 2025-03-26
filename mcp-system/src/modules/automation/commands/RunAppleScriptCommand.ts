import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import { exec } from 'child_process';
import { promisify } from 'util';
import logger from '../../../utils/logger';

const execAsync = promisify(exec);

const RUN_APPLESCRIPT_COMMAND_META: IMCPCommandMeta = {
  name: 'runAppleScript',
  description: 'Execute an AppleScript command or script',
  author: 'MCP System',
};

/**
 * Command to execute AppleScript for system automation
 */
export class RunAppleScriptCommand extends BaseCommand {
  constructor() {
    super(RUN_APPLESCRIPT_COMMAND_META);
  }
  
  public validate(params: IMCPCommandParams): boolean {
    if (!params.script || typeof params.script !== 'string') {
      return false;
    }
    
    return true;
  }
  
  protected async onExecute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    try {
      const script = params.script as string;
      
      logger.info('Executing AppleScript', { scriptLength: script.length });
      
      // Execute the AppleScript
      const { stdout, stderr } = await execAsync(`osascript -e '${script.replace(/'/g, "'\\''")}'`);
      
      if (stderr) {
        logger.warn(`AppleScript execution warning: ${stderr}`);
      }
      
      logger.info('AppleScript executed successfully');
      
      return {
        success: true,
        data: {
          output: stdout.trim(),
        },
        timestamp: Date.now(),
      };
    } catch (error: any) {
      logger.error('Error executing AppleScript', { error });
      
      return {
        success: false,
        error: `Failed to execute AppleScript: ${error.message}`,
        timestamp: Date.now(),
      };
    }
  }
} 