import { MCP } from './core/MCP';
import { IMCPCommandContext } from './interfaces/IMCPCommand';
import logger from './utils/logger';
import dotenv from 'dotenv';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import fs from 'fs-extra';

// Load environment variables
dotenv.config();

/**
 * Main entry point for the MCP system
 */
async function main() {
  try {
    // Create MCP instance
    const mcp = new MCP();
    
    // Initialize MCP
    const initialized = await mcp.initialize({
      logLevel: process.env.LOG_LEVEL || 'info',
      disableSecurity: process.env.DISABLE_SECURITY === 'true',
    });
    
    if (!initialized) {
      logger.error('Failed to initialize MCP system');
      process.exit(1);
    }
    
    // Create command context
    const context: IMCPCommandContext = {
      sessionId: uuidv4(),
      workingDirectory: process.cwd(),
      environmentVars: process.env as Record<string, string>,
      securityContext: {
        isAuthenticated: false,
        permissions: [],
      },
    };
    
    // Register process handlers
    process.on('SIGINT', async () => {
      logger.info('Received SIGINT signal, shutting down...');
      await mcp.shutdown();
      process.exit(0);
    });
    
    process.on('SIGTERM', async () => {
      logger.info('Received SIGTERM signal, shutting down...');
      await mcp.shutdown();
      process.exit(0);
    });
    
    process.on('uncaughtException', async (error) => {
      logger.error('Uncaught exception', { error });
      await mcp.shutdown();
      process.exit(1);
    });
    
    process.on('unhandledRejection', async (reason) => {
      logger.error('Unhandled rejection', { reason });
    });
    
    // Log startup
    logger.info('MCP system started successfully');
    
    // If command line arguments are provided, execute them
    const args = process.argv.slice(2);
    
    if (args.length > 0) {
      const commandString = args.join(' ');
      logger.info(`Executing command: ${commandString}`);
      
      const result = await mcp.executeCommand(commandString, context);
      
      if (result.success) {
        logger.info('Command executed successfully', { result });
        console.log(JSON.stringify(result.data, null, 2));
      } else {
        logger.error('Command execution failed', { result });
        console.error(`Error: ${result.error}`);
        process.exit(1);
      }
      
      // Shutdown MCP
      await mcp.shutdown();
      process.exit(0);
    } else {
      // Start interactive mode or API server here
      logger.info('No command provided, exiting');
      await mcp.shutdown();
      process.exit(0);
    }
  } catch (error) {
    logger.error('Error in main function', { error });
    process.exit(1);
  }
}

// Run main function
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
}); 