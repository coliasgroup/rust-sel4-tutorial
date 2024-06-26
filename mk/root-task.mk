#
# Copyright 2024, Colias Group, LLC
#
# SPDX-License-Identifier: BSD-2-Clause
#

root_dir := $(dir $(lastword $(MAKEFILE_LIST)))/..

build_dir := build

.PHONY: none
none:

.PHONY: clean
clean:
	rm -rf $(build_dir)

$(build_dir):
	mkdir -p $(build_dir)

sel4_prefix := $(SEL4_INSTALL_DIR)

loader_artifacts_dir := $(SEL4_INSTALL_DIR)/bin
loader := $(loader_artifacts_dir)/sel4-kernel-loader
loader_cli := $(loader_artifacts_dir)/sel4-kernel-loader-add-payload

app := $(build_dir)/app.elf

image := $(build_dir)/image.elf

$(image): $(app) $(loader) $(loader_cli)
	$(loader_cli) \
		--loader $(loader) \
		--sel4-prefix $(sel4_prefix) \
		--app $(app) \
		-o $@

qemu_cmd = \
	qemu-system-aarch64 \
		-machine virt,virtualization=on -cpu cortex-a57 -m size=1G \
		-serial mon:stdio \
		-nographic \
		-kernel $(image) \
		$(extra_qemu_args)

.PHONY: simulation-context
simulation-context: $(image)

.PHONY: simulate
simulate: simulation-context
	$(qemu_cmd)

.PHONY: test
test: test.py simulation-context
	PYTHONPATH=$(root_dir)/testing python3 $< $(qemu_cmd)

common_cargo_env := \
	SEL4_PREFIX=$(sel4_prefix)

common_cargo_args := \
	-Z build-std=core,alloc,compiler_builtins \
	-Z build-std-features=compiler-builtins-mem \
	--target-dir $(build_dir)/target \
	--out-dir $(build_dir)
