/*
 * ukernel.h - definitions and system call prototypes for RadiOS microkernel
 */

#ifndef _ukernel_h
#define _ukernel_h

#include <sys/types.h>

int ChannelCreate(unsigned flags);
int ChannelCreate_r(unsigned flags);
int ChannelDestroy(int chid);
int ChannelDestroy_r(int chid);

int ConnectAttach(uint32 nd, pid_t pid, int chid, unsigned index, int flags);
int ConnectAttach_r(uint32 nd, pid_t pid, int chid, unsigned index, int flags);
int ConnectDetach(int coid);
int ConnectDetach_r(int coid);
int ConnectServerInfo(pid_t pid, int coid, struct _server_info *info);
int ConnectServerInfo_r(pid_t pid, int coid, struct _server_info *info);
int ConnectClientInfo(int scoid, struct _client_info *info, int ngroups);
int ConnectClientInfo_r(int scoid, struct _client_info *info, int ngroups);
int ConnectFlags(pid_t pid, int coid, unsigned mask, unsigned bits);
int ConnectFlags_r(pid_t pid, int coid, unsigned mask, unsigned bits);

int MsgSend(int coid, const void *smsg, int sbytes, void *rmsg, int rbytes);
int MsgSend_r(int coid, const void *smsg, int sbytes, void *rmsg, int rbytes);
int MsgSendnc(int coid, const void *smsg, int sbytes, void *rmsg, int rbytes);
int MsgSendnc_r(int coid, const void *smsg, int sbytes, void *rmsg, int rbytes);
int MsgSendsv(int coid, const void *smsg, int sbytes, const struct iovec *riov, int rparts);
int MsgSendsv_r(int coid, const void *smsg, int sbytes, const struct iovec *riov, int rparts);
int MsgSendsvnc(int coid, const void *smsg, int sbytes, const struct iovec *riov, int rparts);
int MsgSendsvnc_r(int coid, const void *smsg, int sbytes, const struct iovec *riov, int rparts);
int MsgSendvs(int coid, const struct iovec *siov, int sparts, void *rmsg, int rbytes);
int MsgSendvs_r(int coid, const struct iovec *siov, int sparts, void *rmsg, int rbytes);
int MsgSendvsnc(int coid, const struct iovec *siov, int sparts, void *rmsg, int rbytes);
int MsgSendvsnc_r(int coid, const struct iovec *siov, int sparts, void *rmsg, int rbytes);
int MsgSendv(int coid, const struct iovec *siov, int sparts, const struct iovec *riov, int rparts);
int MsgSendv_r(int coid, const struct iovec *siov, int sparts, const struct iovec *riov, int rparts);
int MsgSendvnc(int coid, const struct iovec *siov, int sparts, const struct iovec *riov, int rparts);
int MsgSendvnc_r(int coid, const struct iovec *siov, int sparts, const struct iovec *riov, int rparts);
int MsgReceive(int chid, void *msg, int bytes, struct _msg_info *info);
int MsgReceive_r(int chid, void *msg, int bytes, struct _msg_info *info);
int MsgReceivev(int chid, const struct iovec *iov, int parts, struct _msg_info *info);
int MsgReceivev_r(int chid, const struct iovec *iov, int parts, struct _msg_info *info);
int MsgReceivePulse(int chid, void *pulse, int bytes, struct _msg_info *info);
int MsgReceivePulse_r(int chid, void *pulse, int bytes, struct _msg_info *info);
int MsgReceivePulsev(int chid, const struct iovec *iov, int parts, struct _msg_info *info);
int MsgReceivePulsev_r(int chid, const struct iovec *iov, int parts, struct _msg_info *info);
int MsgReply(int rcvid, int status, const void *msg, int bytes);
int MsgReply_r(int rcvid, int status, const void *msg, int bytes);
int MsgReplyv(int rcvid, int status, const struct iovec *iov, int parts);
int MsgReplyv_r(int rcvid, int status, const struct iovec *iov, int parts);
int MsgReadiov(int rcvid, const struct iovec *iov, int parts, int offset, int flags);
int MsgReadiov_r(int rcvid, const struct iovec *iov, int parts, int offset, int flags);
int MsgRead(int rcvid, void *msg, int bytes, int offset);
int MsgRead_r(int rcvid, void *msg, int bytes, int offset);
int MsgReadv(int rcvid, const struct iovec *iov, int parts, int offset);
int MsgReadv_r(int rcvid, const struct iovec *iov, int parts, int offset);
int MsgWrite(int rcvid, const void *msg, int bytes, int offset);
int MsgWrite_r(int rcvid, const void *msg, int bytes, int offset);
int MsgWritev(int rcvid, const struct iovec *iov, int parts, int offset);
int MsgWritev_r(int rcvid, const struct iovec *iov, int parts, int offset);
int MsgSendPulse(int coid, int priority, int code, int value);
int MsgSendPulse_r(int coid, int priority, int code, int value);
int MsgDeliverEvent(int rcvid, const struct sigevent *event);
int MsgDeliverEvent_r(int rcvid, const struct sigevent *event);
int MsgVerifyEvent(int rcvid, const struct sigevent *event);
int MsgVerifyEvent_r(int rcvid, const struct sigevent *event);
int MsgInfo(int rcvid, struct _msg_info *info);
int MsgInfo_r(int rcvid, struct _msg_info *info);
int MsgKeyData(int rcvid, int oper, uint32 key, uint32 *newkey, const struct iovec *iov, int parts);
int MsgKeyData_r(int rcvid, int oper, uint32 key, uint32 *newkey, const struct iovec *iov, int parts);
int MsgError(int rcvid, int err);
int MsgError_r(int rcvid, int err);

int SignalKill(uint32 nd, pid_t pid, int tid, int signo, int code, int value);
int SignalKill_r(uint32 nd, pid_t pid, int tid, int signo, int code, int value);
int SignalReturn(struct _sighandler_info *info);
int SignalAction(pid_t pid, void (*sigstub)(), int signo, const struct sigaction *act, struct sigaction *oact);
int SignalAction_r(pid_t pid, void (*sigstub)(), int signo, const struct sigaction *act, struct sigaction *oact);
int SignalProcmask(pid_t pid, int tid, int how, const sigset_t *set, sigset_t *oldset);
int SignalProcmask_r(pid_t pid, int tid, int how, const sigset_t *set, sigset_t *oldset);
int SignalSuspend(const sigset_t *set);
int SignalSuspend_r(const sigset_t *set);
int SignalWaitinfo(const sigset_t *set, siginfo_t *info);
int SignalWaitinfo_r(const sigset_t *set, siginfo_t *info);

int ThreadCreate(pid_t pid, void *(*func)(void *arg), void *arg, const struct _thread_attr *attr);
int ThreadCreate_r(pid_t pid, void *(*func)(void *arg), void *arg, const struct _thread_attr *attr);
int ThreadDestroy(int tid, int priority, void *status);
int ThreadDestroy_r(int tid, int priority, void *status);
int ThreadDetach(int tid);
int ThreadDetach_r(int tid);
int ThreadJoin(int tid, void **status);
int ThreadJoin_r(int tid, void **status);
int ThreadCancel(int tid, void (*canstub)(void));
int ThreadCancel_r(int tid, void (*canstub)(void));
int ThreadCtl(int cmd, void *data);
int ThreadCtl_r(int cmd, void *data);

struct qtime_entry;

int InterruptHookTrace(const struct sigevent *(*handler)(int), unsigned flags);
int InterruptHookIdle(void (*handler)(uint64 *, struct qtime_entry *), unsigned flags);
int InterruptAttachEvent(int intr, const struct sigevent *event, unsigned flags);
int InterruptAttachEvent_r(int intr, const struct sigevent *event, unsigned flags);
int InterruptAttach(int intr, const struct sigevent *(*handler)(void *area, int id), const void *area, int size, unsigned flags);
int InterruptAttach_r(int intr, const struct sigevent *(*handler)(void *area, int id), const void *area, int size, unsigned flags);
int InterruptDetach(int id);
int InterruptDetach_r(int id);
int InterruptWait(int flags, const uint64 *timeout);
int InterruptWait_r(int flags, const uint64 *timeout);

int SchedGet(pid_t pid, int tid, struct sched_param *param);
int SchedGet_r(pid_t pid, int tid, struct sched_param *param);
int SchedSet(pid_t pid, int tid, int algorithm, const struct sched_param *param);
int SchedSet_r(pid_t pid, int tid, int algorithm, const struct sched_param *param);
int SchedInfo(pid_t pid, int algorithm, struct _sched_info *info);
int SchedInfo_r(pid_t pid, int algorithm, struct _sched_info *info);
int SchedYield(void);
int SchedYield_r(void);

int TimerCreate(clockid_t id, const struct sigevent *notify);
int TimerCreate_r(clockid_t id, const struct sigevent *notify);
int TimerDestroy(timer_t id);
int TimerDestroy_r(timer_t id);
int TimerSettime(timer_t id, int flags, const struct _itimer *itime, struct _itimer *oitime);
int TimerSettime_r(timer_t id, int flags, const struct _itimer *itime, struct _itimer *oitime);
int TimerInfo(pid_t pid, timer_t id, int flags, struct _timer_info *info);
int TimerInfo_r(pid_t pid, timer_t id, int flags, struct _timer_info *info);
int TimerAlarm(clockid_t id, const struct _itimer *itime, struct _itimer *otime);
int TimerAlarm_r(clockid_t id, const struct _itimer *itime, struct _itimer *otime);
int TimerTimeout(clockid_t id, int flags, const struct sigevent *notify, const uint64 *ntime,
							uint64 *otime);
int TimerTimeout_r(clockid_t id, int flags, const struct sigevent *notify, const uint64 *ntime,
							uint64 *otime);

int SyncTypeCreate(unsigned type, sync_t *sync, const struct _sync_attr *attr);
int SyncTypeCreate_r(unsigned type, sync_t *sync, const struct _sync_attr *attr);
int SyncDestroy(sync_t *sync);
int SyncDestroy_r(sync_t *sync);
int SyncCtl(int cmd, sync_t *sync, void *data);
int SyncCtl_r(int cmd, sync_t *sync, void *data);
int SyncMutexEvent(sync_t *sync, struct sigevent *event);
int SyncMutexEvent_r(sync_t *sync, struct sigevent *event);
int SyncMutexLock(sync_t *sync);
int SyncMutexLock_r(sync_t *sync);
int SyncMutexUnlock(sync_t *sync);
int SyncMutexUnlock_r(sync_t *sync);
int SyncMutexRevive(sync_t *sync);
int SyncMutexRevive_r(sync_t *sync);
int SyncCondvarWait(sync_t *sync, sync_t *mutex);
int SyncCondvarWait_r(sync_t *sync, sync_t *mutex);
int SyncCondvarSignal(sync_t *sync, int all);
int SyncCondvarSignal_r(sync_t *sync, int all);
int SyncSemPost(sync_t *sync);
int SyncSemPost_r(sync_t *sync);
int SyncSemWait(sync_t *sync, int tryto);
int SyncSemWait_r(sync_t *sync, int tryto);

int ClockTime(clockid_t id, const uint64 *_new, uint64 *old);
int ClockTime_r(clockid_t id, const uint64 *_new, uint64 *old);
int ClockAdjust(clockid_t id, const struct _clockadjust *_new, struct _clockadjust *old);
int ClockAdjust_r(clockid_t id, const struct _clockadjust *_new, struct _clockadjust *old);
int ClockPeriod(clockid_t id, const struct _clockperiod *_new, struct _clockperiod *old, int reserved);
int ClockPeriod_r(clockid_t id, const struct _clockperiod *_new, struct _clockperiod *old, int reserved);
int ClockId(pid_t pid, int tid);
int ClockId_r(pid_t pid, int tid);

void InterruptEnable(void);
void InterruptDisable(void);
int  InterruptMask(int intr, int id);
int  InterruptUnmask(int intr, int id);
void InterruptLock(struct intrspin * spin);
void InterruptUnlock(struct intrspin * spin);

#endif