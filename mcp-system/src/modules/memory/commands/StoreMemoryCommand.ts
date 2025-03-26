import { BaseCommand } from '../../../core/BaseCommand';
import { IMCPCommandContext, IMCPCommandMeta, IMCPCommandParams, IMCPCommandResult } from '../../../interfaces/IMCPCommand';
import fs from 'fs-extra';
import path from 'path';
import crypto from 'crypto';
import logger from '../../../utils/logger';

const STORE_MEMORY_COMMAND_META: IMCPCommandMeta = {
  name: 'storeMemory',
  description: 'Store a memory in the persistent memory system',
  parameters: [
    {
      name: 'content',
      description: 'The content of the memory to store',
      type: 'string',
      required: true,
    },
    {
      name: 'type',
      description: 'The type of memory (conversation, task, knowledge, etc.)',
      type: 'string',
      required: false,
      default: 'conversation',
    },
    {
      name: 'tags',
      description: 'Tags to associate with the memory for easier retrieval',
      type: 'array',
      required: false,
      default: [],
    },
    {
      name: 'encrypt',
      description: 'Whether to encrypt the memory content',
      type: 'boolean',
      required: false,
      default: false,
    }
  ],
};

/**
 * Command to store a memory in the persistent memory system
 */
export class StoreMemoryCommand extends BaseCommand {
  private memoryDirectory: string;
  
  constructor(memoryDirectory: string) {
    super(STORE_MEMORY_COMMAND_META);
    this.memoryDirectory = memoryDirectory;
  }
  
  public validate(params: IMCPCommandParams): boolean {
    if (!params.content || typeof params.content !== 'string') {
      return false;
    }
    
    return true;
  }
  
  protected async onExecute(
    params: IMCPCommandParams,
    context: IMCPCommandContext
  ): Promise<IMCPCommandResult> {
    try {
      const content = params.content as string;
      const type = (params.type as string) || 'conversation';
      const tags = (params.tags as string[]) || [];
      const encrypt = (params.encrypt as boolean) || false;
      
      // Create a unique ID for the memory
      const id = crypto.randomUUID();
      
      // Create the memory object
      const memory = {
        id,
        content: encrypt ? this.encryptContent(content) : content,
        type,
        tags,
        encrypted: encrypt,
        timestamp: new Date().toISOString(),
        contextId: context.sessionId,
      };
      
      // Ensure the type directory exists
      const typeDirectory = path.join(this.memoryDirectory, type);
      await fs.ensureDir(typeDirectory);
      
      // Write the memory to a file
      const memoryPath = path.join(typeDirectory, `${id}.json`);
      
      // Use atomic write to prevent corruption
      const tempPath = `${memoryPath}.tmp`;
      await fs.writeJson(tempPath, memory, { spaces: 2 });
      await fs.move(tempPath, memoryPath, { overwrite: true });
      
      logger.info(`Memory stored successfully with ID: ${id}`, { type, tags });
      
      return {
        success: true,
        data: {
          id,
          type,
          tags,
          encrypted: encrypt,
        },
        timestamp: Date.now(),
      };
    } catch (error: any) {
      logger.error('Error storing memory', { error });
      
      return {
        success: false,
        error: `Failed to store memory: ${error.message}`,
        timestamp: Date.now(),
      };
    }
  }
  
  /**
   * Encrypt memory content
   * @param content The content to encrypt
   * @returns The encrypted content
   */
  private encryptContent(content: string): string {
    try {
      // In a real implementation, this would use a proper encryption key
      // For now, we'll use a simple encryption for demonstration
      const algorithm = 'aes-256-ctr';
      const secretKey = 'JanetMemoryEncryptionKey'; // This should be stored securely
      const iv = crypto.randomBytes(16);
      
      const cipher = crypto.createCipheriv(algorithm, secretKey, iv);
      const encrypted = Buffer.concat([cipher.update(content), cipher.final()]);
      
      return `${iv.toString('hex')}:${encrypted.toString('hex')}`;
    } catch (error) {
      logger.error('Error encrypting content', { error });
      return content; // Fall back to unencrypted content on error
    }
  }
} 