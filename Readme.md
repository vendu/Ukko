# Ukko

Ukko is the code name for a boot loader project forked from another project
(codenamed Petrichor) to be a community-oriented project and a dedicated boot
loader. At the moment the project includes a bootable floppy with a boot sector written in 16-bit x86 assembly, and a stage-2 image called STAGE2.BIN, written
in 32-bit x86 assembly. The program in the boot sector loads and runs
STAGE2.BIN from the floppy disk. The stage-2 image is a simple, toy program
with demonstration commands.

## Building

To build this project, you willl need:

* NASM 2.12 (http://www.nasm.us/)
* GNU Binutils 2.26 (https://www.gnu.org/software/binutils/)
* GNU Mtools 4.0.17 (https://www.gnu.org/software/mtools/)

Nasm and GNU Mtools may be built and installed in the standard manner for
yoru system. GNU Binutils will have to be build for the i686-elf target.
To build GNU Binutils in this manner, pass the option `--taget=i686-elf`
when running its `configure` script. Make sure this custom build of GNU
Binutils doesn't clobber your system's installation if you have a version
of GNU Binutils installed already.

## Future Development

There are a few goals for the stage-2 image:

* Fit in 64 kibibytes, so that it can be loaded into a single
  segment by the stage-1 image.
* Comply with multiboot standard and load a kernel.

The demonstration aspects of the stage-2 image will eventually be moved into
loadable programs, and a stage-3 kernel will be made to load and run them.
