
	case F_DUPFD: {
		struct _server_info				info;
		int						fd2;
			
		if(fd == -1 || ConnectServerInfo(0, fd, &info) != fd) {
			errno = EBADF;
			return -1;
		}
		if((fd2 = ConnectAttach(info.nd, info.pid, info.chid, va_arg(ap, int), _NTO_COF_CLOEXEC)) == -1) {
			return -1;
		}
		msg.dup.i.type = _IO_DUP;
		msg.dup.i.combine_len = sizeof msg.dup;
		msg.dup.i.info.nd = netmgr_remote_nd(info.nd, ND_LOCAL_NODE);
		msg.dup.i.info.pid = getpid();
		msg.dup.i.info.chid = info.chid;
		msg.dup.i.info.scoid = info.scoid;
		msg.dup.i.info.coid = fd;
		if(MsgSendnc(fd2, &msg.dup.i, sizeof msg.dup.i, 0, 0) == -1) {
			ConnectDetach_r(fd2);
			return -1;
		}
		ConnectFlags_r(0, fd2, FD_CLOEXEC, 0);
		return fd2;
	}


	case F_GETFD:
		return ConnectFlags(0, fd, 0, 0);

	case F_SETFD:
		return ConnectFlags(0, fd, ~0, va_arg(ap, int));
		
	case F_GETFL:
		if(_devctl(fd, DCMD_ALL_GETFLAGS, &arg, sizeof arg, 0) == -1) {
			return -1;
		}
		return arg;

	case F_SETFL:
		arg = va_arg(ap, int);
		return _devctl(fd, DCMD_ALL_SETFLAGS, &arg, sizeof arg, _DEVCTL_FLAG_NORETVAL);

	case F_GETOWN:
		if(_devctl(fd, DCMD_ALL_GETOWN, &pid, sizeof pid, 0) == -1) {
			return -1;
		}
		return pid;
		
	case F_SETOWN:
		pid = va_arg(ap, pid_t);
		return _devctl(fd, DCMD_ALL_SETOWN, &pid, sizeof pid, _DEVCTL_FLAG_NORETVAL);
		
	case F_ALLOCSP64:
	case F_FREESP64: {
		flock64_t	*area = va_arg(ap, flock64_t *);

		msg.space.i.start = area->l_start;
		msg.space.i.len = area->l_len;
		msg.space.i.whence = area->l_whence;
		goto common;
	}
	case F_ALLOCSP:
		cmd = F_ALLOCSP64;	/* Always pass the 64 bit values */
		goto stuff;
	case F_FREESP:
		cmd = F_FREESP64;	/* Always pass the 64 bit values */
stuff: {
		flock_t			*area = va_arg(ap, flock_t *);

		msg.space.i.start = area->l_start;
		msg.space.i.len = area->l_len;
		msg.space.i.whence = area->l_whence;
	}
common:
		msg.space.i.type = _IO_SPACE;
		msg.space.i.combine_len = sizeof msg.space.i;
		msg.space.i.subtype = cmd;
		return MsgSend(fd, &msg.space.i, sizeof msg.space.i, 0, 0);

	case F_GETLK:
	case F_SETLK:
	case F_SETLKW:
	case F_GETLK64:
	case F_SETLK64:
	case F_SETLKW64:
		msg.lock.i.type = _IO_LOCK;
		msg.lock.i.combine_len = sizeof msg.lock.i;
		msg.lock.i.subtype = cmd;
		SETIOV(iov + 0, &msg.lock.i, sizeof msg.lock.i);
		SETIOV(iov + 1, va_arg(ap, flock_t *), sizeof(flock_t));
		iov[3] = iov[1];
		SETIOV(iov + 2, &msg.lock.o, sizeof msg.lock.o);
		return MsgSendv(fd, iov + 0, 2, iov + 2, (cmd == F_GETLK || cmd == F_GETLK64) ? 2 : 1);
		
	default:
		break;
	}

	errno = ENOSYS;
	return -1;
}
