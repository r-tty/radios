/*
 * errno.h - error numbers
 */

#ifndef _errno_h
#define _errno_h

int *get_errno_ptr(void);
#define errno (*__get_errno_ptr())

#define EOK              0  // No error
#define EPERM            1  // Not owner
#define ENOENT           2  // No such file or directory
#define ESRCH            3  // No such process
#define EINTR            4  // Interrupted system call
#define EIO              5  // I/O error
#define ENXIO            6  // No such device or address
#define E2BIG            7  // Arg list too big
#define ENOEXEC          8  // Exec format error
#define EBADF            9  // Bad file number
#define ECHILD          10  // No child processes
#define EAGAIN          11  // Resource unavailable, try again
#define ENOMEM          12  // Not enough space
#define EACCES          13  // Permission denied
#define EFAULT          14  // Bad address
#define ENOTBLK         15  // Block device required
#define EBUSY           16  // Device or resource busy
#define EEXIST          17  // File exists
#define EXDEV           18  // Cross-device link
#define ENODEV          19  // No such device
#define ENOTDIR         20  // Not a directory
#define EISDIR          21  // Is a directory
#define EINVAL          22  // Invalid argument
#define ENFILE          23  // File table overflow
#define EMFILE          24  // Too many open files
#define ENOTTY          25  // Inappropriate I/O control operation
#define ETXTBSY         26  // Text file busy
#define EFBIG           27  // File too large
#define ENOSPC          28  // No space left on device
#define ESPIPE          29  // Illegal seek
#define EROFS           30  // Read-only file system
#define EMLINK          31  // Too many links
#define EPIPE           32  // Broken pipe
#define EDOM            33  // Math argument out of domain of function
#define ERANGE          34  // Result too large
#define ENOMSG          35  // No message of desired type
#define EIDRM           36  // Identifier removed
#define ECHRNG          37  // Channel number out of range
#define EL2NSYNC        38  // Level 2 not synchronized
#define EL3HLT          39  // Level 3 halted
#define EL3RST          40  // Level 3 reset
#define ELNRNG          41  // Link number out of range
#define EUNATCH         42  // Protocol driver not attached
#define ENOCSI          43  // No CSI structure available
#define EL2HLT          44  // Level 2 halted
#define EDEADLK         45  // Deadlock avoided
#define ENOLCK          46  // No locks available in system
#define ECANCELED       47  // Operation canceled (1003.1b-1993)
#define ENOTSUP         48  // Not supported (1003.1b-1993)

#define EDQUOT          49  // Disc quota exceded

#define ENONET          64  // Machine is not on the network
#define ENOPKG          65  // Package not installed
#define EREMOTE         66  // The object is remote
#define ENOLINK         67  // The link has been severed
#define EADV            68  // Advertise error
#define ESRMNT          69  // Srmount error

#define ECOMM           70  // Communication error on send
#define EPROTO          71  // Protocol error
#define EMULTIHOP       74  // multihop attempted
#define EBADMSG         77  // Bad message (1003.1b-1993)
#define ENAMETOOLONG    78  // Name too long
#define EOVERFLOW       79  // Value too large to be stored in data type
#define ENOTUNIQ        80  // Given name not unique
#define EBADFD          81  // FD invalid for this operation
#define EREMCHG         82  // Remote address changed

#define ELIBACC         83  // Can't access shared library
#define ELIBBAD         84  // Accessing a corrupted shared library
#define ELIBSCN         85  // .lib section in a.out corrupted
#define ELIBMAX         86  // Attempting to link in too many libraries
#define ELIBEXEC        87  // Attempting to exec a shared library
#define EILSEQ          88  // Illegal byte sequence

#define ENOSYS          89  // Unknown system call
#define ELOOP           90  // Too many symbolic link or prefix loops
#define ERESTART        91  // Restartable system call
#define ESTRPIPE        92  // if pipe/FIFO, don't sleep in stream head
#define ENOTEMPTY       93  // Directory not empty

#define EOPNOTSUPP      103 // Operation not supported
#define EFPOS		110 // File position error
#define ESTALE          122 // Potentially recoverable i/o error

#endif
