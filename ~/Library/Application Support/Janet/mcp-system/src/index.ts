// If command line arguments are provided, execute them
const args = process.argv.slice(2);

if (args.length > 0) {
  // Check if the first argument is "server"
  if (args[0] === "server") {
    logger.info("Starting MCP server mode");
    
    // Keep the process running
    setInterval(() => {
      // Do nothing, just keep the process alive
    }, 1000);
    
    return;
  }
  
  const commandString = args.join(' ');
  logger.info(`Executing command: ${commandString}`);
  
  // ... existing code ...
} 