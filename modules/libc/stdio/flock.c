/*
 * Based on FreeBSD 5.0 C library.
 * Copyright (c) 1998 John Birrell <jb@cimlogic.com.au>.
 * All rights reserved.
 */

/*
 * POSIX stdio FILE locking functions. These assume that the locking
 * is only required at FILE structure level, not at file descriptor
 * level too.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

void flockfile(FILE *fp)
{
	pthread_t curthread = _pthread_self();

	if (fp->_lock->fl_owner == curthread)
		fp->_lock->fl_count++;
	else {
		/*
		 * Make sure this mutex is treated as a private
		 * internal mutex:
		 */
		_pthread_mutex_lock(&fp->_lock->fl_mutex);
		fp->_lock->fl_owner = curthread;
		fp->_lock->fl_count = 1;
	}
}


int
_ftrylockfile(FILE *fp)
{
	pthread_t curthread = _pthread_self();
	int	ret = 0;

	if (fp->_lock->fl_owner == curthread)
		fp->_lock->fl_count++;
	/*
	 * Make sure this mutex is treated as a private
	 * internal mutex:
	 */
	else if (_pthread_mutex_trylock(&fp->_lock->fl_mutex) == 0) {
		fp->_lock->fl_owner = curthread;
		fp->_lock->fl_count = 1;
	}
	else
		ret = -1;
	return (ret);
}

void 
_funlockfile(FILE *fp)
{
	pthread_t	curthread = _pthread_self();

	/*
	 * Check if this file is owned by the current thread:
	 */
	if (fp->_lock->fl_owner == curthread) {
		/*
		 * Check if this thread has locked the FILE
		 * more than once:
		 */
		if (fp->_lock->fl_count > 1)
			/*
			 * Decrement the count of the number of
			 * times the running thread has locked this
			 * file:
			 */
			fp->_lock->fl_count--;
		else {
			/*
			 * The running thread will release the
			 * lock now:
			 */
			fp->_lock->fl_count = 0;
			fp->_lock->fl_owner = NULL;
			_pthread_mutex_unlock(&fp->_lock->fl_mutex);
		}
	}
}
