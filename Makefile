CC = gcc
CFLAGS = -g -Wall -Werror

LIB_DIR = lib
INCLUDE_DIR = software_model
BUILD_DIR = build

$(BUILD_DIR)/%.o: $(INCLUDE_DIR)/%.c
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) $< -c -o $@

lib/lib%.so: $(BUILD_DIR)/%.o
	mkdir -p $(LIB_DIR)
	$(CC) -shared -o $@ $^

clean:
	rm -rf $(BUILD_DIR) $(LIB_DIR)

