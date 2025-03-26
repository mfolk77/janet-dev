import fs from 'fs-extra';
import path from 'path';
import crypto from 'crypto';
import CryptoJS from 'crypto-js';
import logger from '../utils/logger';

/**
 * User permission level
 */
export enum PermissionLevel {
  NONE = 0,
  READ = 1,
  WRITE = 2,
  EXECUTE = 3,
  ADMIN = 4,
}

/**
 * User data structure
 */
export interface User {
  id: string;
  username: string;
  passwordHash: string;
  salt: string;
  permissions: {
    [category: string]: PermissionLevel;
  };
  apiKeys?: string[];
  createdAt: number;
  lastLogin?: number;
}

/**
 * Authentication result
 */
export interface AuthResult {
  success: boolean;
  userId?: string;
  token?: string;
  error?: string;
}

/**
 * Security manager configuration
 */
export interface SecurityManagerConfig {
  usersFilePath: string;
  tokenSecret: string;
  tokenExpiration: number; // in seconds
  encryptionKey: string;
}

/**
 * Security manager for handling permissions and authentication
 */
export class SecurityManager {
  private users: Map<string, User> = new Map();
  private tokens: Map<string, { userId: string; expires: number }> = new Map();
  private config: SecurityManagerConfig;
  
  /**
   * Create a new security manager
   * @param config Security manager configuration
   */
  constructor(config: SecurityManagerConfig) {
    this.config = config;
  }
  
  /**
   * Initialize the security manager
   */
  public async initialize(): Promise<boolean> {
    try {
      // Ensure the users file exists
      if (!fs.existsSync(this.config.usersFilePath)) {
        await fs.ensureDir(path.dirname(this.config.usersFilePath));
        await fs.writeJSON(this.config.usersFilePath, { users: [] });
      }
      
      // Load users
      const userData = await fs.readJSON(this.config.usersFilePath);
      if (Array.isArray(userData.users)) {
        userData.users.forEach((user: User) => {
          this.users.set(user.id, user);
        });
      }
      
      logger.info(`Loaded ${this.users.size} users`);
      return true;
    } catch (error) {
      logger.error('Failed to initialize security manager', { error });
      return false;
    }
  }
  
  /**
   * Save users to disk
   */
  private async saveUsers(): Promise<void> {
    try {
      const tempPath = `${this.config.usersFilePath}.tmp`;
      await fs.writeJSON(tempPath, { users: Array.from(this.users.values()) });
      await fs.move(tempPath, this.config.usersFilePath, { overwrite: true });
    } catch (error) {
      logger.error('Failed to save users', { error });
      throw error;
    }
  }
  
  /**
   * Create a new user
   * @param username Username
   * @param password Password
   * @param defaultPermissions Default permissions
   */
  public async createUser(
    username: string,
    password: string,
    defaultPermissions: { [category: string]: PermissionLevel } = {}
  ): Promise<User> {
    // Check if username already exists
    const existingUser = Array.from(this.users.values()).find(
      (u) => u.username === username
    );
    if (existingUser) {
      throw new Error(`User ${username} already exists`);
    }
    
    // Generate salt and hash password
    const salt = crypto.randomBytes(16).toString('hex');
    const passwordHash = this.hashPassword(password, salt);
    
    // Create user
    const user: User = {
      id: crypto.randomUUID(),
      username,
      passwordHash,
      salt,
      permissions: {
        ...defaultPermissions,
        system: PermissionLevel.READ,
      },
      createdAt: Date.now(),
    };
    
    // Save user
    this.users.set(user.id, user);
    await this.saveUsers();
    
    return user;
  }
  
  /**
   * Authenticate a user
   * @param username Username
   * @param password Password
   */
  public async authenticate(username: string, password: string): Promise<AuthResult> {
    // Find user
    const user = Array.from(this.users.values()).find(
      (u) => u.username === username
    );
    if (!user) {
      return { success: false, error: 'Invalid username or password' };
    }
    
    // Check password
    const passwordHash = this.hashPassword(password, user.salt);
    if (passwordHash !== user.passwordHash) {
      return { success: false, error: 'Invalid username or password' };
    }
    
    // Generate token
    const token = this.generateToken(user.id);
    
    // Update last login
    user.lastLogin = Date.now();
    await this.saveUsers();
    
    return { success: true, userId: user.id, token };
  }
  
  /**
   * Authenticate with API key
   * @param apiKey API key
   */
  public async authenticateWithApiKey(apiKey: string): Promise<AuthResult> {
    // Find user with API key
    const user = Array.from(this.users.values()).find(
      (u) => u.apiKeys && u.apiKeys.includes(apiKey)
    );
    if (!user) {
      return { success: false, error: 'Invalid API key' };
    }
    
    // Generate token
    const token = this.generateToken(user.id);
    
    // Update last login
    user.lastLogin = Date.now();
    await this.saveUsers();
    
    return { success: true, userId: user.id, token };
  }
  
  /**
   * Validate a token
   * @param token Token to validate
   */
  public validateToken(token: string): { valid: boolean; userId?: string } {
    const tokenData = this.tokens.get(token);
    if (!tokenData) {
      return { valid: false };
    }
    
    // Check if token is expired
    if (tokenData.expires < Date.now()) {
      this.tokens.delete(token);
      return { valid: false };
    }
    
    return { valid: true, userId: tokenData.userId };
  }
  
  /**
   * Check if a user has permission
   * @param userId User ID
   * @param category Permission category
   * @param level Required permission level
   */
  public hasPermission(
    userId: string,
    category: string,
    level: PermissionLevel
  ): boolean {
    const user = this.users.get(userId);
    if (!user) {
      return false;
    }
    
    // Check if user has admin permission
    if (user.permissions.admin === PermissionLevel.ADMIN) {
      return true;
    }
    
    // Check specific permission
    const userLevel = user.permissions[category] || PermissionLevel.NONE;
    return userLevel >= level;
  }
  
  /**
   * Generate a token for a user
   * @param userId User ID
   */
  private generateToken(userId: string): string {
    const token = crypto.randomBytes(32).toString('hex');
    const expires = Date.now() + this.config.tokenExpiration * 1000;
    
    this.tokens.set(token, { userId, expires });
    
    return token;
  }
  
  /**
   * Hash a password
   * @param password Password to hash
   * @param salt Salt
   */
  private hashPassword(password: string, salt: string): string {
    return crypto
      .pbkdf2Sync(password, salt, 10000, 64, 'sha512')
      .toString('hex');
  }
  
  /**
   * Encrypt data
   * @param data Data to encrypt
   */
  public encrypt(data: string): string {
    return CryptoJS.AES.encrypt(data, this.config.encryptionKey).toString();
  }
  
  /**
   * Decrypt data
   * @param encryptedData Encrypted data
   */
  public decrypt(encryptedData: string): string {
    const bytes = CryptoJS.AES.decrypt(encryptedData, this.config.encryptionKey);
    return bytes.toString(CryptoJS.enc.Utf8);
  }
} 