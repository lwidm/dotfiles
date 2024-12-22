# scripst/Makefile

BUILD_DIR := build
BIN_DIR := bin
SRC_DIR := src
# INC_DIR := include

# Compiler settings
CC := clang
CXX := clang++
# CPPFLAGS := -I $(INC_DIR) -DVERSION=1.0
CPPFLAGS := -DVERSION=1.0
CFLAGS := -O2
CXXFLAGS := $(CFLAGS) -std=c++11
# LDFLAGS := -shared -O2 -flto
LDFLAGS := -O2 -flto

# Terget settings
ifeq ($(OS),Windows_NT)
	TARGETS := format_number.exe
	EXE_EXT := .exe
	OBJ_EXT := obj
	PLATFORM_DIR := windows
	NULL_DEVICE := NULL
else
	TARGETS := format_number
	EXE_EXT := 
	OBJ_EXT := o
	PLATFORM_DIR := linux
	NULL_DEVICE := /dev/null
endif

# BUILD_DIR := $(BUILD_DIR)/$(PLATFORM_DIR)
BUILD_DIR := $(BUILD_DIR)
# BIN_DIR := $(BIN_DIR)/$(PLATFORM_DIR)
BIN_DIR := $(BIN_DIR)

SRC_FILES := $(wildcard $(SRC_DIR)/*.cpp)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.cpp, $(BUILD_DIR)/%.$(OBJ_EXT), $(SRC_FILES))
JSON_FILES := $(patsubst $(SRC_DIR)/%.cpp, $(BUILD_DIR)/%.json, $(SRC_FILES))
COMPILATION_DB := $(BUILD_DIR)/compile_commands.json

.PHONY: all clean compile_commands

all: $(BIN_DIR)/$(TARGETS) compile_commands

$(BUILD__DIR):
	mkdir -p $@

$(BUILD_DIR)/.gitignore:
	echo '*' > $@

$(BIN_DIR):
	mkdir -p $@

# Compile each .cpp file to an object file
$(BUILD_DIR)/%.$(OBJ_EXT): $(SRC_DIR)/%.cpp | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

# Link all object files into the shared library
# $(BIN_DIR)/$(TARGETS): $(OBJ_FILES) | $(BIN_DIR)
	# $(CXX) $(LDFLAGS) $^ -o $@
$(BIN_DIR)/format_number$(EXE_EXT) : $(BUILD_DIR)/format_number.$(OBJ_EXT) | $(BIN_DIR)
	$(CXX) $(LDFLAGS) $^ -o $@

# Compile each .cpp file to a JSON fragment
$(BUILD_DIR)/%.json: $(SRC_DIR)/%.cpp | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) -MJ $@ -c $< -o $(NULL_DEVICE)

./compile_commands.json: $(JSON_FILES)
	echo '[' > $(COMPILATION_DB)
	$(foreach file, $(JSON_FILES), cat $(file) >> $(COMPILATION_DB);)
	sed -i '$$ s/,$$//' $(COMPILATION_DB)
	echo ']' >> $(COMPILATION_DB)
	cp $(COMPILATION_DB) ./compile_commands.json

compile_commands: ./compile_commands.json

clean:
	rm -rf \
		$(BUILD_DIR)/*.$(OBJ_EXT) \
		$(BIN_DIR)/$(TARGETS) \
		$(BIN_DIR)/*.lib \
		$(BIN_DIR)/*.exp \
		$(BUILD_DIR)/*.json \
		./compile_commands.json

