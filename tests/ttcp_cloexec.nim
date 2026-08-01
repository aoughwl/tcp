## ttcp_cloexec.nim — every socket this library opens must be close-on-exec.
##
## Sockets are inheritable by default. Without FD_CLOEXEC every descriptor
## leaks into any child process: a child that outlives the parent keeps a
## listening port bound, and an accepted connection is handed to a process that
## was never meant to see it. Nothing here set the flag.
##
## Checks all four ways this library produces a descriptor: a listener, a
## blocking connect, a nonblocking connect, and an accepted socket.

import std/syncio
import tcp

proc fcntlRaw(fd, cmd: cint): cint {.varargs, importc: "fcntl", header: "<fcntl.h>".}
var F_GETFD_T {.importc: "F_GETFD", header: "<fcntl.h>".}: cint
var FD_CLOEXEC_T {.importc: "FD_CLOEXEC", header: "<fcntl.h>".}: cint

proc check(ok: bool; msg: string) =
  if not ok:
    echo "FAIL: ", msg
    quit(1)

proc isCloseOnExec(fd: TcpHandle): bool =
  let flags = fcntlRaw(cint(fd), F_GETFD_T)
  if flags < 0: return false
  (flags and FD_CLOEXEC_T) != 0.cint

proc main =
  initTcp()

  let lfd = listenTcp4(0x7f000001'u32, 0)
  check(isValidTcp(lfd), "listen")
  check(isCloseOnExec(lfd), "listener is close-on-exec")
  let port = localTcpEndpoint(lfd).port
  check(port > 0, "ephemeral port")

  # blocking connect
  let cfd = connectTcp4(0x7f000001'u32, port)
  check(isValidTcp(cfd), "connect")
  check(isCloseOnExec(cfd), "connected socket is close-on-exec")

  # the accepted side
  let afd = acceptTcp(lfd)
  check(isValidTcp(afd), "accept")
  check(isCloseOnExec(afd), "accepted socket is close-on-exec")

  closeTcp(afd)
  closeTcp(cfd)

  # nonblocking connect
  let nb = connectTcp4NonBlocking(0x7f000001'u32, port)
  check(isValidTcp(nb.handle), "nonblocking connect")
  check(isCloseOnExec(nb.handle), "nonblocking socket is close-on-exec")
  closeTcp(nb.handle)

  closeTcp(lfd)
  shutdownTcp()
  echo "ttcp_cloexec: all checks passed"

main()
