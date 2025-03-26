import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs-extra';
import path from 'path';
import logger from '../../../utils/logger';

const execAsync = promisify(exec);

const LOCAL_MODEL_COMMAND_META: IMCPCommandMeta = {
  name: 'localModel',
  description: 'Execute a prompt using a local LLM via llama.cpp',
  version: '1.0.0',
  author: 'MCP System',
  parameters: [
    {
      name: 'prompt',
      description: 'The prompt to send to the model',
      type: 'string',
      required: true,
    },
    {
      name: 'model',
      description: 'The model to use (e.g., mistral-7b, llama3, codellama)',
      type: 'string',
      required: false,
      default: 'mistral-7b',
    },
    {
      name: 'maxTokens',
      description: 'Maximum number of tokens to generate',
      type: 'number',
      required: false,
      default: 2048,
    },
    {
      name: 'temperature',
      description: 'Sampling temperature',
      type: 'number',
      required: false,
      default: 0.7,
    }
  ],
};

/**
 * Command to execute a prompt using a local LLM via llama.cpp
 */
export class LocalModelCommand extends BaseCommand {
  private modelsDirectory: string;
  
  constructor() {
    super(LOCAL_MODEL_COMMAND_META);
    // Set the models directory to ~/Library/Application Support/Janet/models
    this.modelsDirectory = path.join(process.env.HOME || '~', 'Library', 'Application Support', 'Janet', 'models');
  }
  
  public validate(params: IMCPCommandParams): boolean {
    if (!params.prompt || typeof params.prompt !== 'string') {
      return false;
    }
    
    return true;
  }
  
  protected async onExecute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    try {
      const prompt = params.prompt as string;
      const modelName = (params.model as string) || 'mistral-7b';
      const maxTokens = (params.maxTokens as number) || 2048;
      const temperature = (params.temperature as number) || 0.7;
      
      // Determine the model path
      const modelPath = this.getModelPath(modelName);
      
      if (!modelPath) {
        return {
          success: false,
          error: `Model ${modelName} not found in ${this.modelsDirectory}`,
          timestamp: Date.now(),
        };
      }
      
      logger.info(`Executing prompt with local model ${modelName}`, { modelPath });
      
      // Execute llama.cpp with the model
      const llamaCommand = `llama -m ${modelPath} -n ${maxTokens} -t ${temperature} -p "${prompt.replace(/"/g, '\\"')}"`;
      
      const { stdout, stderr } = await execAsync(llamaCommand);
      
      if (stderr) {
        logger.warn(`Local model execution warning: ${stderr}`);
      }
      
      return {
        success: true,
        data: {
          output: stdout,
          model: modelName,
        },
        timestamp: Date.now(),
      };
    } catch (error: any) {
      logger.error('Error executing local model', { error });
      
      return {
        success: false,
        error: `Failed to execute local model: ${error.message}`,
        timestamp: Date.now(),
      };
    }
  }
  
  /**
   * Get the path to a model file
   * @param modelName The name of the model
   * @returns The path to the model file, or undefined if not found
   */
  private getModelPath(modelName: string): string | undefined {
    try {
      // Ensure the models directory exists
      if (!fs.existsSync(this.modelsDirectory)) {
        fs.mkdirpSync(this.modelsDirectory);
        return undefined;
      }
      
      // Check for exact model file
      const exactPath = path.join(this.modelsDirectory, modelName);
      if (fs.existsSync(exactPath) && fs.statSync(exactPath).isFile()) {
        return exactPath;
      }
      
      // Check for model file with extensions
      const extensions = ['.bin', '.gguf', '.ggml'];
      for (const ext of extensions) {
        const pathWithExt = path.join(this.modelsDirectory, `${modelName}${ext}`);
        if (fs.existsSync(pathWithExt) && fs.statSync(pathWithExt).isFile()) {
          return pathWithExt;
        }
      }
      
      // Check for model in subdirectory
      const subdirPath = path.join(this.modelsDirectory, modelName);
      if (fs.existsSync(subdirPath) && fs.statSync(subdirPath).isDirectory()) {
        // Look for model files in the subdirectory
        const files = fs.readdirSync(subdirPath);
        for (const file of files) {
          if (file.endsWith('.bin') || file.endsWith('.gguf') || file.endsWith('.ggml')) {
            return path.join(subdirPath, file);
          }
        }
      }
      
      // Model not found
      return undefined;
    } catch (error) {
      logger.error('Error finding model path', { error, modelName });
      return undefined;
    }
  }
} 