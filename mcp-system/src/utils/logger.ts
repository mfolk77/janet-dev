import winston from 'winston';
import path from 'path';
import fs from 'fs-extra';

/**
 * Logger configuration options
 */
export interface LoggerOptions {
  logLevel?: string;
  logDirectory?: string;
  logFilename?: string;
  consoleOutput?: boolean;
}

/**
 * Create a logger instance
 * @param options Logger configuration options
 * @returns Winston logger instance
 */
export function createLogger(options: LoggerOptions = {}): winston.Logger {
  const {
    logLevel = 'info',
    logDirectory = path.join(process.cwd(), 'logs'),
    logFilename = 'mcp.log',
    consoleOutput = true,
  } = options;

  // Ensure log directory exists
  fs.ensureDirSync(logDirectory);

  const logPath = path.join(logDirectory, logFilename);

  // Define log format
  const logFormat = winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  );

  // Define console format (more readable)
  const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.printf(({ level, message, timestamp, ...meta }) => {
      return `${timestamp} ${level}: ${message} ${
        Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''
      }`;
    })
  );

  // Create transports
  const transports: winston.transport[] = [
    new winston.transports.File({
      filename: logPath,
      level: logLevel,
      format: logFormat,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
    }),
  ];

  // Add console transport if enabled
  if (consoleOutput) {
    transports.push(
      new winston.transports.Console({
        level: logLevel,
        format: consoleFormat,
      })
    );
  }

  // Create and return logger
  return winston.createLogger({
    level: logLevel,
    transports,
    exitOnError: false,
  });
}

// Create default logger
const defaultLogger = createLogger();

export default defaultLogger; 