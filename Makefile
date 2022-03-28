CC = gcc
CFLAGS = -g -Wall -Werror
DEFINE = SOFTWARE_MODEL_ONLY

LIB_DIR = lib
INCLUDE_DIR = software_model
BUILD_DIR = build

TARGET = main

all: ${TARGET}

$(BUILD_DIR)/%.o: $(INCLUDE_DIR)/%.c
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -I. $< -c -o $@

lib/lib%.so: $(BUILD_DIR)/%.o
	mkdir -p $(LIB_DIR)
	$(CC) $(CFLAGS) -shared -o $@ $^

%: test/%.c $(BUILD_DIR)/utils.o $(BUILD_DIR)/bilinear_scaling.o
	$(CC) $(CFLAGS) $^ -I. -D ${DEFINE} -o $(BUILD_DIR)/$@

clean:
	rm -rf $(BUILD_DIR) $(LIB_DIR)

