/*
 * multiboot.h - multiboot header definitions.
 */

#ifndef _sys_multiboot_h
#define _sys_multiboot_h

/* The magic number for the Multiboot header */
#define MULTIBOOT_HEADER_MAGIC		0x1BADB002

/* The flags for the Multiboot header */
#ifdef __ELF__
# define MULTIBOOT_HEADER_FLAGS		0x00000003
#else
# define MULTIBOOT_HEADER_FLAGS		0x00010003
#endif

/* The magic number passed by a Multiboot-compliant boot loader */
#define MULTIBOOT_LOADER_MAGIC		0x2BADB002

/* The Multiboot header */
typedef struct {
  unsigned long magic;
  unsigned long flags;
  unsigned long checksum;
  unsigned long header_addr;
  unsigned long load_addr;
  unsigned long load_end_addr;
  unsigned long bss_end_addr;
  unsigned long entry_addr;
} tMultibootHeader;

/* The symbol table for a.out */
typedef struct {
  unsigned long tabsize;
  unsigned long strsize;
  unsigned long addr;
  unsigned long reserved;
} tAoutSymbolTable;

/* The section header table for ELF */
typedef struct {
  unsigned long num;
  unsigned long size;
  unsigned long addr;
  unsigned long shndx;
} tElfSectHeaderTable;

/* The Multiboot information */
typedef struct {
  unsigned long flags;
  unsigned long mem_lower;
  unsigned long mem_upper;
  unsigned long boot_device;
  unsigned long cmdline;
  unsigned long mods_count;
  unsigned long mods_addr;
  union
  {
    tAoutSymbolTable aout_sym;
    tElfSectHeaderTable elf_sec;
  } u;
  unsigned long mmap_length;
  unsigned long mmap_addr;
  unsigned long drives_length;
  unsigned long drives_addr;
  unsigned long config_table;
  unsigned long boot_loader_name;
  unsigned long apm_table;
} tMultibootInfo;

/* Flags to be set in the 'flags' parameter above */

/* is there basic lower/upper memory information? */
#define MB_INFO_MEMORY          1

/* is there a boot device set? */
#define MB_INFO_BOOTDEV         2

/* is the command-line defined? */
#define MB_INFO_CMDLINE         4

/* are there modules to do something with? */
#define MB_INFO_MODS            8

/* is there a full memory map? */
#define MB_INFO_MEM_MAP         0x40

/* is there BIOS configuration table? */
#define MB_INFO_BIOS_CONFIG	0x100

/* can we figure out the name of our boot loader? */
#define MB_INFO_BOOTLD_NAME	0x200

/* The module structure */
typedef struct {
  unsigned long mod_start;
  unsigned long mod_end;
  unsigned long string;
  unsigned long reserved;
} tBootModule;

/*
 * BIOS memory map.
 * Be careful that the offset 0 is base_addr_low but no size.
 */
typedef struct {
  unsigned long size;
  unsigned long base_addr_low;
  unsigned long base_addr_high;
  unsigned long length_low;
  unsigned long length_high;
  unsigned long type;
} tBIOSMemoryMap;

#endif
