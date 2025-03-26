CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = JanetHelper
INSTALL_DIR = /Library/PrivilegedHelperTools/com.FolkAI.JanetHelper

all: $(TARGET)

$(TARGET): JanetHelper.c
	$(CC) $(CFLAGS) -o $(TARGET) JanetHelper.c

install: $(TARGET)
	@echo "Installing $(TARGET) to $(INSTALL_DIR)"
	@sudo mkdir -p $(INSTALL_DIR)
	@sudo cp $(TARGET) $(INSTALL_DIR)/
	@sudo chown root:wheel $(INSTALL_DIR)/$(TARGET)
	@sudo chmod 4755 $(INSTALL_DIR)/$(TARGET)
	@echo "Installation complete"

clean:
	rm -f $(TARGET)

.PHONY: all install clean 