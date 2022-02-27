# Makefile contributed by jtsiomb

src = bootle.asm

.PHONY: all
all: bootle.img bootle.com

bootle.img: $(src)
	nasm -f bin -o $@ $(src)

bootle.com: $(src)
	nasm -f bin -o $@ -Dcom_file=1 $(src)

.PHONY: clean
clean:
	$(RM) bootle.img bootle.com

.PHONY: rundosbox
rundosbox: bootle.com
	dosbox $<

.PHONY: runqemu
runqemu: bootle.img
	qemu-system-i386 -fda bootle.img
