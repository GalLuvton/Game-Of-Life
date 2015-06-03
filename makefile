ifndef DEBUG
DEBUG = 0
endif

CFLAGS = -g -f elf

ifneq ($(DEBUG),0)
        CFLAGS += -D _print
endif

# All Targets
all: ./ass3


./ass3: ./bin/scheduler.o ./bin/printer.o ./bin/coroutines.o ./bin/ass3.o
	ld -g -melf_i386 -o ./ass3 ./bin/scheduler.o ./bin/printer.o ./bin/coroutines.o ./bin/ass3.o

./bin/scheduler.o: scheduler.s
	nasm $(CFLAGS) scheduler.s -o ./bin/scheduler.o

./bin/printer.o: printer.s
	nasm $(CFLAGS) printer.s -o ./bin/printer.o

./bin/coroutines.o: coroutines.s
	nasm $(CFLAGS) coroutines.s -o ./bin/coroutines.o

./bin/ass3.o: ass3.s
	nasm $(CFLAGS) ass3.s -o ./bin/ass3.o

.PHONY:
	clean

#Clean the build directory
clean:
	rm -f ./bin/*.o ./ass3
