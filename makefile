PROGRAM = qik
ZC = zig

main:
	rm -rf $(PROGRAM)
	$(ZC) build-exe --name $(PROGRAM) src/main.zig
	rm -rf $(PROGRAM).o

run: main
	./$(PROGRAM)
