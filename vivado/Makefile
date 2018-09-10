CONFIG_FILE := Makefile.config
include $(CONFIG_FILE)

HW_FILELIST := $(HW_SRC_DIR)/file.list
HW_TESTLIST := test.list
HW_SRC_FILES := $(shell cat $(HW_FILELIST) | egrep -v '\#' | grep -v "tb" | grep -v "include")
VERILOG_SOURCES := $(HW_SRC_FILES:%=$(HW_SRC_DIR)/%)

PROJ_TCL := ../tcl/project/ku115.tcl
PROJ_NAME := vivado
LOG_DIR := ./log
OUTPUT_DIR := ./synthesis-output

BITFILE ?= $(OUTPUT_DIR)/ku115_wrapper.bit

all: $(BITFILE)

$(BITFILE): log_dir $(VERILOG_SOURCES)
	@vivado -mode batch \
		-notrace \
		-nojournal \
		-log $(LOG_DIR)/vivado.log \
		-source $(PROJ_TCL) \
		-tclargs \
		--origin_dir $(HW_SRC_DIR) \
		--project_name $(PROJ_NAME) | grep DnnWeaver2

# program: $(BITFILE)
program:
	@vivado -mode batch \
		-notrace \
		-nojournal \
		-log ./log/vivado.log \
		-source program.tcl \
		-tclargs --bitfile $(BITFILE)

log_dir:
	@mkdir -p $(LOG_DIR)
	@mkdir -p ./synthesis-output

.PHONY: clean
clean:
	rm -r $(LOG_DIR)
	rm -r $(PROJ_NAME)
	rm -r $(OUTPUT_DIR)
