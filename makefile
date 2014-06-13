
# All Targets
all: ./bin/ass3


./bin/ass3: ./bin/scheduler.o ./bin/printer.o ./bin/coroutines.o ./bin/ass3.o
	ld -g -melf_i386 -o ./bin/ass3 ./bin/scheduler.o ./bin/printer.o ./bin/coroutines.o ./bin/ass3.o

./bin/scheduler.o: scheduler.s
	nasm -g -f elf scheduler.s -o ./bin/scheduler.o

./bin/printer.o: printer.s
	nasm -g -f elf printer.s -o ./bin/printer.o

./bin/coroutines.o: coroutines.s
	nasm -g -f elf coroutines.s -o ./bin/coroutines.o

./bin/ass3.o: ass3.s
	nasm -g -f elf ass3.s -o ./bin/ass3.o

.PHONY:
	clean

#Clean the build directory
clean:
	rm -f ./bin/*.o ./bin/ass3
