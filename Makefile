TARGET := riscv64gc-unknown-none-elf
MODE := release
KERNEL_ELF := target/$(TARGET)/$(MODE)/miaos
KERNEL_BIN := $(KERNEL_ELF).bin
# Binutils
OBJDUMP := rust-objdump --arch-name=riscv64
OBJCOPY := rust-objcopy --binary-architecture=riscv64

$(KERNEL_BIN): kernel
	@$(OBJCOPY) $(KERNEL_ELF) --strip-all -O binary $@

kernel:
	@cargo build --release

KERNEL_ENTRY_PA := 0x80200000

BOARD                ?= qemu
SBI                  ?= rustsbi
BOOTLOADER   := ./bootloader/$(SBI)-$(BOARD).bin

build: $(KERNEL_BIN)
run: run-inner

run-inner: build
	@qemu-system-riscv64 \
      -machine virt \
      -nographic \
      -bios $(BOOTLOADER) \
      -device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY_PA)

debug: build
	@tmux new-session -d \
		"qemu-system-riscv64 -machine virt -nographic -bios $(BOOTLOADER) -device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY_PA) -s -S" && \
		tmux split-window -h "riscv64-unknown-elf-gdb -ex 'file $(KERNEL_ELF)' -ex 'set arch riscv:rv64' -ex 'target remote localhost:1234'" && \
		tmux -2 attach-session -d

gdb: build
	qemu-system-riscv64 -machine virt -nographic -bios $(BOOTLOADER) -device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY_PA) -s -S

clean:
	@cargo clean

.PHONY: build kernel clean run-inner