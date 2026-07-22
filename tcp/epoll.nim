## tcp/epoll.nim — our own thin epoll(7) binding, the readiness primitive the
## reactor is built on. Native, no shim, no framework runtime — same house
## style as `tcp/native.nim`. Linux-only (epoll is a Linux facility); the flag
## constants are the stable kernel ABI values.

# ---------------------------------------------------------------------------
# constants (Linux ABI, stable)
# ---------------------------------------------------------------------------

const
  EPOLLIN* = 0x001'u32
  EPOLLOUT* = 0x004'u32
  EPOLLERR* = 0x008'u32
  EPOLLHUP* = 0x010'u32
  EPOLLRDHUP* = 0x2000'u32

  EPOLL_CTL_ADD = 1.cint
  EPOLL_CTL_DEL = 2.cint
  EPOLL_CTL_MOD = 3.cint

  EPOLL_CLOEXEC = 0x80000.cint   # O_CLOEXEC

# ---------------------------------------------------------------------------
# the epoll_event struct + syscalls (importc, real kernel header)
# ---------------------------------------------------------------------------

type
  EpollData {.importc: "epoll_data_t", header: "<sys/epoll.h>", union.} = object
    fd {.importc: "fd".}: cint
    u64 {.importc: "u64".}: uint64

  EpollEvent {.importc: "struct epoll_event", header: "<sys/epoll.h>".} = object
    events {.importc: "events".}: uint32
    data {.importc: "data".}: EpollData

proc epoll_create1(flags: cint): cint
  {.importc: "epoll_create1", header: "<sys/epoll.h>".}
proc epoll_ctl(epfd, op, fd: cint; event: ptr EpollEvent): cint
  {.importc: "epoll_ctl", header: "<sys/epoll.h>".}
proc epoll_wait(epfd: cint; events: ptr EpollEvent; maxevents, timeout: cint): cint
  {.importc: "epoll_wait", header: "<sys/epoll.h>".}

# ---------------------------------------------------------------------------
# high-level wrappers used by the reactor
# ---------------------------------------------------------------------------

proc epollCreate*(): cint =
  ## Create an epoll instance (CLOEXEC). Returns the epoll fd, or -1 on failure.
  epoll_create1(EPOLL_CLOEXEC)

proc epollAdd*(epfd, fd: cint; mask: uint32) =
  var ev = EpollEvent(events: mask)
  ev.data.fd = fd
  discard epoll_ctl(epfd, EPOLL_CTL_ADD, fd, addr ev)

proc epollMod*(epfd, fd: cint; mask: uint32) =
  var ev = EpollEvent(events: mask)
  ev.data.fd = fd
  discard epoll_ctl(epfd, EPOLL_CTL_MOD, fd, addr ev)

proc epollDel*(epfd, fd: cint) =
  # event arg is ignored for DEL on modern kernels but pass a valid pointer.
  var ev = EpollEvent(events: 0'u32)
  discard epoll_ctl(epfd, EPOLL_CTL_DEL, fd, addr ev)

type
  EventBuf* = object
    ## A reusable buffer of epoll_event slots the reactor waits into.
    slots: seq[EpollEvent]

proc newEventBuf*(n: int): EventBuf =
  result = EventBuf(slots: newSeq[EpollEvent](n))

proc epollWait*(epfd: cint; buf: var EventBuf; timeoutMs: cint): int =
  ## Block until at least one fd is ready (or timeout). Returns the number of
  ## ready events (0 on timeout, -1 on error). EINTR is surfaced as -1; the
  ## caller re-enters the loop.
  epoll_wait(epfd, addr buf.slots[0], cint(buf.slots.len), timeoutMs)

proc eventFd*(buf: var EventBuf; i: int): cint =
  ## The fd of the i-th ready event.
  buf.slots[i].data.fd

proc eventMask*(buf: var EventBuf; i: int): uint32 =
  buf.slots[i].events
