CC = gcc
CFLAGS = -g -Wall -Werror

LIB_DIR = lib
INCLUDE_DIR = software_model
BUILD_DIR = build

TARGET = main

$(BUILD_DIR)/%.o: $(INCLUDE_DIR)/%.c
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) $< -c -o $@

lib/lib%.so: $(BUILD_DIR)/%.o
	mkdir -p $(LIB_DIR)
	$(CC) $(CFLAGS) -shared -o $@ $^

%: test/%.c $(BUILD_DIR)/utils.o
	$(CC) $(CFLAGS) $^ -I$(INCLUDE_DIR) -o $(BUILD_DIR)/$@

clean:
	rm -rf $(BUILD_DIR) $(LIB_DIR)

