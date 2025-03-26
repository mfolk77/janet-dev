/**
 * Interface for MCP command execution results
 */
export interface IMCPCommandResult {
  success: boolean;
  data?: any;
  error?: string;
  timestamp: number;
  executionTime?: number;
}

/**
 * Interface for MCP command parameters
 */
export interface IMCPCommandParams {
  [key: string]: any;
}

/**
 * Interface for MCP command metadata
 */
export interface IMCPCommandMeta {
  name: string;
  description: string;
  version?: string;
  author?: string;
  parameters?: Array<{
    name: string;
    description: string;
    type: string;
    required: boolean;
    default?: any;
  }>;
  category?: string;
  requiresAuth?: boolean;
  permissions?: string[];
}

/**
 * Interface for MCP command execution context
 */
export interface IMCPCommandContext {
  userId?: string;
  sessionId: string;
  workingDirectory: string;
  environmentVars: Record<string, string>;
  securityContext: {
    permissions: string[];
    isAuthenticated: boolean;
    authToken?: string;
  };
}

/**
 * Interface for MCP command implementation
 */
export interface IMCPCommand {
  meta: IMCPCommandMeta;
  execute(params: IMCPCommandParams, context: IMCPCommandContext): Promise<IMCPCommandResult>;
  validate?(params: IMCPCommandParams): boolean;
  help(): string;
} 