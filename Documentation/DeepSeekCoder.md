# DeepSeek Coder Integration

## Overview

The DeepSeek Coder integration adds specialized code generation capabilities to Janet. DeepSeek Coder is a state-of-the-art code language model trained on a high-quality code corpus, excelling at code generation, understanding, and editing tasks across multiple programming languages.

## Features

- **Code Generation**: Generate code in multiple programming languages based on natural language prompts.
- **Code Testing**: Test the model's performance across different coding tasks and compare with other models.
- **Performance Metrics**: Track and analyze the model's performance over time.
- **Multiple Model Versions**: Support for different DeepSeek Coder model variants (6.7B, 33B, Instruct).

## Requirements

- Ollama installed and running on your system
- DeepSeek Coder model pulled in Ollama (`ollama pull deepseek-coder:6.7b`)
- Janet application with the latest updates

## Getting Started

1. **Install Ollama**: If you haven't already, install Ollama from [ollama.ai](https://ollama.ai).

2. **Pull the DeepSeek Coder model**:
   ```bash
   ollama pull deepseek-coder:6.7b
   ```

3. **Launch Janet**: Start the Janet application.

4. **Access DeepSeek Coder**: Navigate to the DeepSeek Coder view in Janet.

## Usage

### Generating Code

1. Select the programming language from the dropdown menu.
2. Enter your prompt describing the code you want to generate.
3. Click "Generate Code" to create the code.
4. Copy the generated code to your clipboard using the copy button.

### Testing the Model

1. Go to the Testing tab.
2. Click "Run Tests" to evaluate the model's performance across different coding tasks.
3. View the test results to see how well the model performs.

### Comparing with Other Models

1. Go to the Testing tab.
2. Click "Compare Models" to compare DeepSeek Coder with other models like Phi and Llama3.
3. View the comparison results to see which model performs best for different tasks.

### Changing Model Version

1. Go to the Settings tab.
2. Select the desired model version from the dropdown menu.
3. Click "Pull Model" if you need to download the selected model.

## Architecture

The DeepSeek Coder integration consists of the following components:

- **DeepSeekCoderManager**: Manages the DeepSeek Coder model, handling requests, tracking performance, and managing model versions.
- **CodeModelTester**: Tests the model's performance across different coding tasks and compares it with other models.
- **DeepSeekCoderView**: Provides a user interface for interacting with the DeepSeek Coder model.

## Troubleshooting

### Model Not Available

If the model is not available:

1. Check if Ollama is running.
2. Verify that you have pulled the DeepSeek Coder model.
3. Try pulling the model again from the Settings tab.

### Generation Fails

If code generation fails:

1. Check the error message for details.
2. Ensure your prompt is clear and specific.
3. Try using a different model version.
4. Restart Ollama and try again.

## Performance Considerations

- The 6.7B model is faster but may have lower quality outputs.
- The 33B model is slower but generally produces higher quality code.
- Consider using the Instruct version for more precise control over the output.

## Future Improvements

- Integration with code editors for in-editor code generation.
- Fine-tuning capabilities for customizing the model to specific coding styles or domains.
- Support for more advanced code generation features like test generation and documentation generation.

## References

- [DeepSeek Coder GitHub Repository](https://github.com/deepseek-ai/DeepSeek-Coder)
- [Ollama Documentation](https://ollama.ai/docs)
- [Janet Documentation](https://janet.ai/docs) 