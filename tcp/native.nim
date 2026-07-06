## tcp/native.aowl — native blocking TCP primitives.
##
## This module binds directly to platform socket APIs. It uses no C shim and no
## framework runtime.

when defined(windows):
  type
    TcpHandle* = uint
    WSAData {.importc: "WSADATA", header: "<winsock2.h>".} = object
    SockAddr {.importc: "struct sockaddr", header: "<winsock2.h>".} = object
    InAddr {.importc: "struct in_addr", header: "<winsock2.h>".} = object
      s_addr*: uint32
    SockaddrIn {.importc: "struct sockaddr_in", header: "<winsock2.h>".} = object
      sin_family*: cushort
      sin_port*: cushort
      sin_addr*: InAddr

  const
    InvalidTcpHandle* = not 0'u
    AF_INET = 2.cint
    SOCK_STREAM = 1.cint
    IPPROTO_TCP = 6.cint
    SOL_SOCKET = 0xffff.cint
    SO_REUSEADDR = 4.cint
    INADDR_ANY = 0'u32

  proc WSAStartup(wVersionRequested: cushort; lpWSAData: ptr WSAData): cint {.
    stdcall, importc: "WSAStartup", dynlib: "ws2_32.dll".}
  proc WSACleanup(): cint {.stdcall, importc: "WSACleanup", dynlib: "ws2_32.dll".}
  proc socket(af, typ, protocol: cint): TcpHandle {.
    stdcall, importc: "socket", dynlib: "ws2_32.dll".}
  proc setsockopt(s: TcpHandle; level, optname: cint; optval: pointer; optlen: cint): cint {.
    stdcall, importc: "setsockopt", dynlib: "ws2_32.dll".}
  proc bindSocket(s: TcpHandle; name: ptr SockAddr; namelen: cint): cint {.
    stdcall, importc: "bind", dynlib: "ws2_32.dll".}
  proc listenSocket(s: TcpHandle; backlog: cint): cint {.
    stdcall, importc: "listen", dynlib: "ws2_32.dll".}
  proc acceptSocket(s: TcpHandle; name: ptr SockAddr; namelen: ptr cint): TcpHandle {.
    stdcall, importc: "accept", dynlib: "ws2_32.dll".}
  proc recvSocket(s: TcpHandle; buf: pointer; len, flags: cint): cint {.
    stdcall, importc: "recv", dynlib: "ws2_32.dll".}
  proc sendSocket(s: TcpHandle; buf: pointer; len, flags: cint): cint {.
    stdcall, importc: "send", dynlib: "ws2_32.dll".}
  proc closeSocket(s: TcpHandle): cint {.
    stdcall, importc: "closesocket", dynlib: "ws2_32.dll".}
  proc htons(x: cushort): cushort {.
    stdcall, importc: "htons", dynlib: "ws2_32.dll".}

  var tcpStarted = false

  proc initTcp*() =
    if not tcpStarted:
      var data = default(WSAData)
      discard WSAStartup(0x0202.cushort, addr data)
      tcpStarted = true

  proc shutdownTcp*() =
    if tcpStarted:
      discard WSACleanup()
      tcpStarted = false

else:
  type
    TcpHandle* = cint
    SockLen = cuint
    SockAddr {.importc: "struct sockaddr", header: "<sys/socket.h>".} = object
    InAddr {.importc: "struct in_addr", header: "<netinet/in.h>".} = object
      s_addr*: uint32
    SockaddrIn {.importc: "struct sockaddr_in", header: "<netinet/in.h>".} = object
      sin_family*: cushort
      sin_port*: cushort
      sin_addr*: InAddr

  const
    InvalidTcpHandle* = -1.cint
    AF_INET = 2.cint
    SOCK_STREAM = 1.cint
    IPPROTO_TCP = 6.cint
    SOL_SOCKET = 1.cint
    SO_REUSEADDR = 2.cint
    INADDR_ANY = 0'u32

  proc socket(af, typ, protocol: cint): TcpHandle {.
    importc: "socket", header: "<sys/socket.h>".}
  proc setsockopt(s: TcpHandle; level, optname: cint; optval: pointer; optlen: SockLen): cint {.
    importc: "setsockopt", header: "<sys/socket.h>".}
  proc bindSocket(s: TcpHandle; name: ptr SockAddr; namelen: SockLen): cint {.
    importc: "bind", header: "<sys/socket.h>".}
  proc listenSocket(s: TcpHandle; backlog: cint): cint {.
    importc: "listen", header: "<sys/socket.h>".}
  proc acceptSocket(s: TcpHandle; name: ptr SockAddr; namelen: ptr SockLen): TcpHandle {.
    importc: "accept", header: "<sys/socket.h>".}
  proc recvSocket(s: TcpHandle; buf: pointer; len: csize_t; flags: cint): int {.
    importc: "recv", header: "<sys/socket.h>".}
  proc sendSocket(s: TcpHandle; buf: pointer; len: csize_t; flags: cint): int {.
    importc: "send", header: "<sys/socket.h>".}
  proc closeSocket(s: TcpHandle): cint {.
    importc: "close", header: "<unistd.h>".}
  proc htons(x: cushort): cushort {.
    importc: "htons", header: "<arpa/inet.h>".}

  proc initTcp*() =
    discard

  proc shutdownTcp*() =
    discard

proc listenTcp*(port: int; backlog = 128): TcpHandle =
  let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
  if fd == InvalidTcpHandle:
    return InvalidTcpHandle
  var yes: cint = 1
  when defined(windows):
    discard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, addr yes, cint(sizeof(yes)))
  else:
    discard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, addr yes, SockLen(sizeof(yes)))

  var addr4 = default(SockaddrIn)
  addr4.sin_family = cushort(AF_INET)
  addr4.sin_port = htons(cushort(port))
  addr4.sin_addr.s_addr = INADDR_ANY

  when defined(windows):
    if bindSocket(fd, cast[ptr SockAddr](addr addr4), cint(sizeof(addr4))) != 0:
      discard closeSocket(fd)
      return InvalidTcpHandle
  else:
    if bindSocket(fd, cast[ptr SockAddr](addr addr4), SockLen(sizeof(addr4))) != 0:
      discard closeSocket(fd)
      return InvalidTcpHandle

  if listenSocket(fd, backlog.cint) != 0:
    discard closeSocket(fd)
    return InvalidTcpHandle
  return fd

proc acceptTcp*(listenFd: TcpHandle): TcpHandle =
  var addr4 = default(SockaddrIn)
  when defined(windows):
    var addrLen = cint(sizeof(addr4))
    acceptSocket(listenFd, cast[ptr SockAddr](addr addr4), addr addrLen)
  else:
    var addrLen = SockLen(sizeof(addr4))
    acceptSocket(listenFd, cast[ptr SockAddr](addr addr4), addr addrLen)

proc readTcp*(fd: TcpHandle; buf: pointer; len: int): int =
  when defined(windows):
    result = recvSocket(fd, buf, len.cint, 0).int
  else:
    result = recvSocket(fd, buf, len.csize_t, 0)

proc writeTcp*(fd: TcpHandle; buf: pointer; len: int): int =
  when defined(windows):
    result = sendSocket(fd, buf, len.cint, 0).int
  else:
    result = sendSocket(fd, buf, len.csize_t, 0)

proc closeTcp*(fd: TcpHandle) =
  if fd != InvalidTcpHandle:
    discard closeSocket(fd)

proc isValidTcp*(fd: TcpHandle): bool =
  fd != InvalidTcpHandle

proc writeAllTcp*(fd: TcpHandle; buf: pointer; len: int): int =
  ## Write up to `len` bytes, retrying short writes until complete or error.
  result = 0
  while result < len:
    let n = writeTcp(fd, cast[pointer](cast[uint](buf) + uint(result)), len - result)
    if n <= 0:
      return result
    result = result + n
