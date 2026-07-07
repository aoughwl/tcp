## tcp/native.nim — native blocking TCP primitives.
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
    AddrInfo {.importc: "struct addrinfo", header: "<ws2tcpip.h>".} = object
      ai_flags*: cint
      ai_family*: cint
      ai_socktype*: cint
      ai_protocol*: cint
      ai_addrlen*: csize_t
      ai_canonname*: nil cstring
      ai_addr*: ptr SockAddr
      ai_next*: AddrInfoPtr
    AddrInfoPtr = nil ptr AddrInfo
    PollFd {.importc: "WSAPOLLFD", header: "<winsock2.h>".} = object
      fd*: TcpHandle
      events*: cshort
      revents*: cshort

    TcpErrorKind* = enum
      tcpErrorNone,
      tcpErrorRetry,
      tcpErrorTimeout,
      tcpErrorInterrupted,
      tcpErrorDisconnected,
      tcpErrorRefused,
      tcpErrorUnreachable,
      tcpErrorUnknown

    TcpConnectStatus* = enum
      tcpConnectFailed,
      tcpConnectInProgress,
      tcpConnectConnected

    TcpEndpoint* = object
      address*: uint32
      port*: int

    TcpConnectResult* = object
      handle*: TcpHandle
      status*: TcpConnectStatus
      errorCode*: int

  const
    InvalidTcpHandle* = not 0'u
    AF_INET = 2.cint
    SOCK_STREAM = 1.cint
    IPPROTO_TCP = 6.cint
    SOL_SOCKET = 0xffff.cint
    SO_REUSEADDR = 4.cint
    SO_KEEPALIVE = 8.cint
    SO_SNDTIMEO = 0x1005.cint
    SO_RCVTIMEO = 0x1006.cint
    SO_ERROR = 0x1007.cint
    TCP_NODELAY = 1.cint
    SD_RECEIVE = 0.cint
    SD_SEND = 1.cint
    SD_BOTH = 2.cint
    FIONBIO = 0x8004667e.clong
    PollIn = 0x0300.cshort
    PollOut = 0x0010.cshort
    PollErr = 0x0001.cshort
    PollHup = 0x0002.cshort
    PollNval = 0x0004.cshort
    WSAEINTR = 10004
    WSAEWOULDBLOCK = 10035
    WSAEINPROGRESS = 10036
    WSAEALREADY = 10037
    WSAENETDOWN = 10050
    WSAENETUNREACH = 10051
    WSAENETRESET = 10052
    WSAECONNABORTED = 10053
    WSAECONNRESET = 10054
    WSAENOTCONN = 10057
    WSAESHUTDOWN = 10058
    WSAETIMEDOUT = 10060
    WSAECONNREFUSED = 10061
    WSAEHOSTUNREACH = 10065
    INADDR_ANY = 0'u32

  proc WSAStartup(wVersionRequested: cushort; lpWSAData: ptr WSAData): cint {.
    stdcall, importc: "WSAStartup", dynlib: "ws2_32.dll".}
  proc WSACleanup(): cint {.stdcall, importc: "WSACleanup", dynlib: "ws2_32.dll".}
  proc WSAGetLastError(): cint {.
    stdcall, importc: "WSAGetLastError", dynlib: "ws2_32.dll".}
  proc socket(af, typ, protocol: cint): TcpHandle {.
    stdcall, importc: "socket", dynlib: "ws2_32.dll".}
  proc setsockopt(s: TcpHandle; level, optname: cint; optval: pointer; optlen: cint): cint {.
    stdcall, importc: "setsockopt", dynlib: "ws2_32.dll".}
  proc getsockopt(s: TcpHandle; level, optname: cint; optval: pointer; optlen: ptr cint): cint {.
    stdcall, importc: "getsockopt", dynlib: "ws2_32.dll".}
  proc bindSocket(s: TcpHandle; name: ptr SockAddr; namelen: cint): cint {.
    stdcall, importc: "bind", dynlib: "ws2_32.dll".}
  proc connectSocket(s: TcpHandle; name: ptr SockAddr; namelen: cint): cint {.
    stdcall, importc: "connect", dynlib: "ws2_32.dll".}
  proc listenSocket(s: TcpHandle; backlog: cint): cint {.
    stdcall, importc: "listen", dynlib: "ws2_32.dll".}
  proc acceptSocket(s: TcpHandle; name: ptr SockAddr; namelen: ptr cint): TcpHandle {.
    stdcall, importc: "accept", dynlib: "ws2_32.dll".}
  proc getsockname(s: TcpHandle; name: ptr SockAddr; namelen: ptr cint): cint {.
    stdcall, importc: "getsockname", dynlib: "ws2_32.dll".}
  proc getpeername(s: TcpHandle; name: ptr SockAddr; namelen: ptr cint): cint {.
    stdcall, importc: "getpeername", dynlib: "ws2_32.dll".}
  proc recvSocket(s: TcpHandle; buf: pointer; len, flags: cint): cint {.
    stdcall, importc: "recv", dynlib: "ws2_32.dll".}
  proc sendSocket(s: TcpHandle; buf: pointer; len, flags: cint): cint {.
    stdcall, importc: "send", dynlib: "ws2_32.dll".}
  proc shutdownSocket(s: TcpHandle; how: cint): cint {.
    stdcall, importc: "shutdown", dynlib: "ws2_32.dll".}
  proc closeSocket(s: TcpHandle): cint {.
    stdcall, importc: "closesocket", dynlib: "ws2_32.dll".}
  proc ioctlsocket(s: TcpHandle; cmd: clong; argp: ptr culong): cint {.
    stdcall, importc: "ioctlsocket", dynlib: "ws2_32.dll".}
  proc WSAPoll(fdarray: ptr PollFd; nfds: culong; timeout: cint): cint {.
    stdcall, importc: "WSAPoll", dynlib: "ws2_32.dll".}
  proc htons(x: cushort): cushort {.
    stdcall, importc: "htons", dynlib: "ws2_32.dll".}
  proc htonl(x: uint32): uint32 {.
    stdcall, importc: "htonl", dynlib: "ws2_32.dll".}
  proc ntohs(x: cushort): cushort {.
    stdcall, importc: "ntohs", dynlib: "ws2_32.dll".}
  proc ntohl(x: uint32): uint32 {.
    stdcall, importc: "ntohl", dynlib: "ws2_32.dll".}
  proc getaddrinfo(node, service: nil cstring; hints: AddrInfoPtr; res: ptr AddrInfoPtr): cint {.
    stdcall, importc: "getaddrinfo", dynlib: "ws2_32.dll".}
  proc freeaddrinfo(res: AddrInfoPtr) {.
    stdcall, importc: "freeaddrinfo", dynlib: "ws2_32.dll".}

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

  proc lastTcpErrorCode*(): int =
    ## Return the last platform socket error code for the current thread.
    WSAGetLastError().int

  proc classifyTcpErrorCode*(code: int): TcpErrorKind =
    ## Classify a platform socket error code into portable socket categories.
    if code == 0:
      tcpErrorNone
    elif code == WSAEWOULDBLOCK or code == WSAEINPROGRESS or code == WSAEALREADY:
      tcpErrorRetry
    elif code == WSAETIMEDOUT:
      tcpErrorTimeout
    elif code == WSAEINTR:
      tcpErrorInterrupted
    elif code == WSAENETDOWN or code == WSAENETUNREACH or code == WSAENETRESET or
        code == WSAECONNABORTED or code == WSAECONNRESET or code == WSAENOTCONN or
        code == WSAESHUTDOWN:
      tcpErrorDisconnected
    elif code == WSAECONNREFUSED:
      tcpErrorRefused
    elif code == WSAEHOSTUNREACH:
      tcpErrorUnreachable
    else:
      tcpErrorUnknown

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
    AddrInfo {.importc: "struct addrinfo", header: "<netdb.h>".} = object
      ai_flags*: cint
      ai_family*: cint
      ai_socktype*: cint
      ai_protocol*: cint
      ai_addrlen*: SockLen
      ai_addr*: ptr SockAddr
      ai_canonname*: nil cstring
      ai_next*: AddrInfoPtr
    AddrInfoPtr = nil ptr AddrInfo
    PollFd {.importc: "struct pollfd", header: "<poll.h>".} = object
      fd*: cint
      events*: cshort
      revents*: cshort
    TimeVal {.importc: "struct timeval", header: "<sys/time.h>".} = object
      tv_sec*: clong
      tv_usec*: clong

    TcpErrorKind* = enum
      tcpErrorNone,
      tcpErrorRetry,
      tcpErrorTimeout,
      tcpErrorInterrupted,
      tcpErrorDisconnected,
      tcpErrorRefused,
      tcpErrorUnreachable,
      tcpErrorUnknown

    TcpConnectStatus* = enum
      tcpConnectFailed,
      tcpConnectInProgress,
      tcpConnectConnected

    TcpEndpoint* = object
      address*: uint32
      port*: int

    TcpConnectResult* = object
      handle*: TcpHandle
      status*: TcpConnectStatus
      errorCode*: int

  const
    InvalidTcpHandle* = -1.cint
    AF_INET = 2.cint
    SOCK_STREAM = 1.cint
    IPPROTO_TCP = 6.cint
    TCP_NODELAY = 1.cint
    SHUT_RD = 0.cint
    SHUT_WR = 1.cint
    SHUT_RDWR = 2.cint
    PollIn = 0x001.cshort
    PollOut = 0x004.cshort
    PollErr = 0x008.cshort
    PollHup = 0x010.cshort
    PollNval = 0x020.cshort
    INADDR_ANY = 0'u32

  proc socket(af, typ, protocol: cint): TcpHandle {.
    importc: "socket", header: "<sys/socket.h>".}
  proc setsockopt(s: TcpHandle; level, optname: cint; optval: pointer; optlen: SockLen): cint {.
    importc: "setsockopt", header: "<sys/socket.h>".}
  proc getsockopt(s: TcpHandle; level, optname: cint; optval: pointer; optlen: ptr SockLen): cint {.
    importc: "getsockopt", header: "<sys/socket.h>".}
  proc bindSocket(s: TcpHandle; name: ptr SockAddr; namelen: SockLen): cint {.
    importc: "bind", header: "<sys/socket.h>".}
  proc connectSocket(s: TcpHandle; name: ptr SockAddr; namelen: SockLen): cint {.
    importc: "connect", header: "<sys/socket.h>".}
  proc listenSocket(s: TcpHandle; backlog: cint): cint {.
    importc: "listen", header: "<sys/socket.h>".}
  proc acceptSocket(s: TcpHandle; name: ptr SockAddr; namelen: ptr SockLen): TcpHandle {.
    importc: "accept", header: "<sys/socket.h>".}
  proc getsockname(s: TcpHandle; name: ptr SockAddr; namelen: ptr SockLen): cint {.
    importc: "getsockname", header: "<sys/socket.h>".}
  proc getpeername(s: TcpHandle; name: ptr SockAddr; namelen: ptr SockLen): cint {.
    importc: "getpeername", header: "<sys/socket.h>".}
  proc recvSocket(s: TcpHandle; buf: pointer; len: csize_t; flags: cint): int {.
    importc: "recv", header: "<sys/socket.h>".}
  proc sendSocket(s: TcpHandle; buf: pointer; len: csize_t; flags: cint): int {.
    importc: "send", header: "<sys/socket.h>".}
  proc shutdownSocket(s: TcpHandle; how: cint): cint {.
    importc: "shutdown", header: "<sys/socket.h>".}
  proc closeSocket(s: TcpHandle): cint {.
    importc: "close", header: "<unistd.h>".}
  proc fcntl(fd, cmd: cint): cint {.varargs, importc: "fcntl", header: "<fcntl.h>".}
  proc poll(fds: ptr PollFd; nfds: culong; timeout: cint): cint {.
    importc: "poll", header: "<poll.h>".}
  proc htons(x: cushort): cushort {.
    importc: "htons", header: "<arpa/inet.h>".}
  proc htonl(x: uint32): uint32 {.
    importc: "htonl", header: "<arpa/inet.h>".}
  proc ntohs(x: cushort): cushort {.
    importc: "ntohs", header: "<arpa/inet.h>".}
  proc ntohl(x: uint32): uint32 {.
    importc: "ntohl", header: "<arpa/inet.h>".}
  proc getaddrinfo(node, service: nil cstring; hints: AddrInfoPtr; res: ptr AddrInfoPtr): cint {.
    importc: "getaddrinfo", header: "<netdb.h>".}
  proc freeaddrinfo(res: AddrInfoPtr) {.
    importc: "freeaddrinfo", header: "<netdb.h>".}

  var EAGAIN {.importc: "EAGAIN", header: "<errno.h>".}: cint
  var EWOULDBLOCK {.importc: "EWOULDBLOCK", header: "<errno.h>".}: cint
  var EINPROGRESS {.importc: "EINPROGRESS", header: "<errno.h>".}: cint
  var EALREADY {.importc: "EALREADY", header: "<errno.h>".}: cint
  var ETIMEDOUT {.importc: "ETIMEDOUT", header: "<errno.h>".}: cint
  var EINTR {.importc: "EINTR", header: "<errno.h>".}: cint
  var ENETDOWN {.importc: "ENETDOWN", header: "<errno.h>".}: cint
  var ENETUNREACH {.importc: "ENETUNREACH", header: "<errno.h>".}: cint
  var ECONNABORTED {.importc: "ECONNABORTED", header: "<errno.h>".}: cint
  var ECONNRESET {.importc: "ECONNRESET", header: "<errno.h>".}: cint
  var ENOTCONN {.importc: "ENOTCONN", header: "<errno.h>".}: cint
  var EPIPE {.importc: "EPIPE", header: "<errno.h>".}: cint
  var ECONNREFUSED {.importc: "ECONNREFUSED", header: "<errno.h>".}: cint
  var EHOSTUNREACH {.importc: "EHOSTUNREACH", header: "<errno.h>".}: cint
  var SOL_SOCKET {.importc: "SOL_SOCKET", header: "<sys/socket.h>".}: cint
  var SO_REUSEADDR {.importc: "SO_REUSEADDR", header: "<sys/socket.h>".}: cint
  var SO_KEEPALIVE {.importc: "SO_KEEPALIVE", header: "<sys/socket.h>".}: cint
  var SO_SNDTIMEO {.importc: "SO_SNDTIMEO", header: "<sys/socket.h>".}: cint
  var SO_RCVTIMEO {.importc: "SO_RCVTIMEO", header: "<sys/socket.h>".}: cint
  var SO_ERROR {.importc: "SO_ERROR", header: "<sys/socket.h>".}: cint
  var F_GETFL {.importc: "F_GETFL", header: "<fcntl.h>".}: cint
  var F_SETFL {.importc: "F_SETFL", header: "<fcntl.h>".}: cint
  var O_NONBLOCK {.importc: "O_NONBLOCK", header: "<fcntl.h>".}: cint

  when defined(macosx) or defined(freebsd) or defined(openbsd) or defined(netbsd):
    proc errnoLocation(): ptr cint {.importc: "__error", header: "<errno.h>".}
  else:
    proc errnoLocation(): ptr cint {.importc: "__errno_location", header: "<errno.h>".}

  proc initTcp*() =
    discard

  proc shutdownTcp*() =
    discard

  proc lastTcpErrorCode*(): int =
    ## Return the last platform socket error code for the current thread.
    let p = errnoLocation()
    if p == nil:
      return 0
    p[].int

  proc classifyTcpErrorCode*(code: int): TcpErrorKind =
    ## Classify a platform socket error code into portable socket categories.
    let err = code.cint
    if err == 0:
      tcpErrorNone
    elif err == EAGAIN or err == EWOULDBLOCK or err == EINPROGRESS or err == EALREADY:
      tcpErrorRetry
    elif err == ETIMEDOUT:
      tcpErrorTimeout
    elif err == EINTR:
      tcpErrorInterrupted
    elif err == ENETDOWN or err == ENETUNREACH or err == ECONNABORTED or
        err == ECONNRESET or err == ENOTCONN or err == EPIPE:
      tcpErrorDisconnected
    elif err == ECONNREFUSED:
      tcpErrorRefused
    elif err == EHOSTUNREACH:
      tcpErrorUnreachable
    else:
      tcpErrorUnknown

proc lastTcpErrorKind*(): TcpErrorKind =
  classifyTcpErrorCode(lastTcpErrorCode())

proc tcpErrorWouldRetry*(code: int): bool =
  classifyTcpErrorCode(code) == tcpErrorRetry

proc tcpErrorTimedOut*(code: int): bool =
  classifyTcpErrorCode(code) == tcpErrorTimeout

proc tcpErrorInterrupted*(code: int): bool =
  classifyTcpErrorCode(code) == tcpErrorInterrupted

proc tcpErrorDisconnected*(code: int): bool =
  let kind = classifyTcpErrorCode(code)
  kind == tcpErrorDisconnected or kind == tcpErrorRefused or kind == tcpErrorUnreachable

type
  TcpPollRequest* = object
    read*: bool
    write*: bool

  TcpPollResult* = object
    read*: bool
    write*: bool
    error*: bool
    hangup*: bool
    invalid*: bool

proc setTcpBlocking*(fd: TcpHandle; blocking: bool): bool =
  ## Switch a socket between blocking and nonblocking mode.
  if fd == InvalidTcpHandle:
    return false
  when defined(windows):
    var mode: culong = 1
    if blocking:
      mode = 0
    result = ioctlsocket(fd, FIONBIO, addr mode) == 0
  else:
    let flags = fcntl(fd, F_GETFL)
    if flags < 0:
      return false
    var next = flags
    if blocking:
      next = flags and not O_NONBLOCK
    else:
      next = flags or O_NONBLOCK
    result = fcntl(fd, F_SETFL, next) == 0

proc setTcpNonBlocking*(fd: TcpHandle): bool =
  ## Convenience wrapper for `setTcpBlocking(fd, false)`.
  setTcpBlocking(fd, false)

proc pollTcp*(fd: TcpHandle; request: TcpPollRequest; timeoutMillis: int;
              ready: var TcpPollResult): int =
  ## Wait for socket readiness. Returns >0 ready, 0 timeout, or <0 error.
  ready = TcpPollResult(read: false, write: false, error: false, hangup: false, invalid: false)
  if fd == InvalidTcpHandle:
    ready.invalid = true
    return -1
  var events: cshort = 0
  if request.read:
    events = events or PollIn
  if request.write:
    events = events or PollOut
  var pfd = PollFd(fd: fd, events: events, revents: 0)
  when defined(windows):
    let n = WSAPoll(addr pfd, 1.culong, timeoutMillis.cint)
  else:
    let n = poll(addr pfd, 1.culong, timeoutMillis.cint)
  if n <= 0:
    return n.int
  ready.read = (pfd.revents and PollIn) != 0
  ready.write = (pfd.revents and PollOut) != 0
  ready.error = (pfd.revents and PollErr) != 0
  ready.hangup = (pfd.revents and PollHup) != 0
  ready.invalid = (pfd.revents and PollNval) != 0
  n.int

proc waitTcpReadable*(fd: TcpHandle; timeoutMillis: int): bool =
  var request = TcpPollRequest(read: true, write: false)
  var ready = default(TcpPollResult)
  pollTcp(fd, request, timeoutMillis, ready) > 0 and ready.read

proc waitTcpWritable*(fd: TcpHandle; timeoutMillis: int): bool =
  var request = TcpPollRequest(read: false, write: true)
  var ready = default(TcpPollResult)
  pollTcp(fd, request, timeoutMillis, ready) > 0 and ready.write

proc tcpSocketErrorCode*(fd: TcpHandle; errorCode: var int): bool =
  ## Read the pending SO_ERROR value.
  if fd == InvalidTcpHandle:
    errorCode = -1
    return false
  var value: cint = 0
  when defined(windows):
    var valueLen = cint(sizeof(value))
    if getsockopt(fd, SOL_SOCKET, SO_ERROR, addr value, addr valueLen) != 0:
      errorCode = lastTcpErrorCode()
      return false
  else:
    var valueLen = SockLen(sizeof(value))
    if getsockopt(fd, SOL_SOCKET, SO_ERROR, addr value, addr valueLen) != 0:
      errorCode = lastTcpErrorCode()
      return false
  errorCode = value.int
  true

proc tcpSocketErrorCode*(fd: TcpHandle): int =
  ## Return the pending SO_ERROR value, or -1 if it cannot be read.
  var errorCode = 0
  if tcpSocketErrorCode(fd, errorCode):
    return errorCode
  -1

proc finishTcpConnect*(fd: TcpHandle): bool =
  ## Check whether a nonblocking connect completed successfully.
  tcpSocketErrorCode(fd) == 0

proc finishTcpConnect*(fd: TcpHandle; errorCode: var int): bool =
  ## Check whether a nonblocking connect completed successfully.
  if not tcpSocketErrorCode(fd, errorCode):
    return false
  errorCode == 0

proc listenTcp4*(hostOrderAddr: uint32; port: int; backlog = 128): TcpHandle =
  ## Listen on an IPv4 address encoded in host byte order.
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
  addr4.sin_addr.s_addr = htonl(hostOrderAddr)

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

proc listenTcp*(port: int; backlog = 128): TcpHandle =
  listenTcp4(INADDR_ANY, port, backlog)

proc invalidTcpEndpoint*(): TcpEndpoint =
  TcpEndpoint(address: 0'u32, port: -1)

proc endpointFromSockaddr(addr4: SockaddrIn): TcpEndpoint =
  TcpEndpoint(
    address: ntohl(addr4.sin_addr.s_addr),
    port: int(ntohs(addr4.sin_port))
  )

proc localTcpEndpoint*(fd: TcpHandle): TcpEndpoint =
  ## Return the socket's bound IPv4 address and port, or an invalid endpoint.
  if fd == InvalidTcpHandle:
    return invalidTcpEndpoint()
  var addr4 = default(SockaddrIn)
  when defined(windows):
    var addrLen = cint(sizeof(addr4))
    if getsockname(fd, cast[ptr SockAddr](addr addr4), addr addrLen) != 0:
      return invalidTcpEndpoint()
  else:
    var addrLen = SockLen(sizeof(addr4))
    if getsockname(fd, cast[ptr SockAddr](addr addr4), addr addrLen) != 0:
      return invalidTcpEndpoint()
  endpointFromSockaddr(addr4)

proc peerTcpEndpoint*(fd: TcpHandle): TcpEndpoint =
  ## Return the connected peer's IPv4 address and port, or an invalid endpoint.
  if fd == InvalidTcpHandle:
    return invalidTcpEndpoint()
  var addr4 = default(SockaddrIn)
  when defined(windows):
    var addrLen = cint(sizeof(addr4))
    if getpeername(fd, cast[ptr SockAddr](addr addr4), addr addrLen) != 0:
      return invalidTcpEndpoint()
  else:
    var addrLen = SockLen(sizeof(addr4))
    if getpeername(fd, cast[ptr SockAddr](addr addr4), addr addrLen) != 0:
      return invalidTcpEndpoint()
  endpointFromSockaddr(addr4)

proc setTcpBoolOpt(fd: TcpHandle; level, optname: cint; enabled: bool): bool =
  if fd == InvalidTcpHandle:
    return false
  var flag: cint = 0
  if enabled:
    flag = 1
  when defined(windows):
    result = setsockopt(fd, level, optname, addr flag, cint(sizeof(flag))) == 0
  else:
    result = setsockopt(fd, level, optname, addr flag, SockLen(sizeof(flag))) == 0

proc setTcpMillisOpt(fd: TcpHandle; optname: cint; millis: int): bool =
  if fd == InvalidTcpHandle or millis < 0:
    return false
  when defined(windows):
    var timeout = millis.cint
    result = setsockopt(fd, SOL_SOCKET, optname, addr timeout, cint(sizeof(timeout))) == 0
  else:
    var timeout = default(TimeVal)
    timeout.tv_sec = clong(millis div 1000)
    timeout.tv_usec = clong((millis mod 1000) * 1000)
    result = setsockopt(fd, SOL_SOCKET, optname, addr timeout, SockLen(sizeof(timeout))) == 0

proc setTcpNoDelay*(fd: TcpHandle; enabled = true): bool =
  ## Enable or disable TCP_NODELAY for latency-sensitive small writes.
  setTcpBoolOpt(fd, IPPROTO_TCP, TCP_NODELAY, enabled)

proc setTcpKeepAlive*(fd: TcpHandle; enabled = true): bool =
  ## Enable or disable platform-default TCP keepalive.
  setTcpBoolOpt(fd, SOL_SOCKET, SO_KEEPALIVE, enabled)

proc setTcpReadTimeoutMillis*(fd: TcpHandle; millis: int): bool =
  ## Bound blocking reads. Pass 0 to restore platform blocking behavior.
  setTcpMillisOpt(fd, SO_RCVTIMEO, millis)

proc setTcpWriteTimeoutMillis*(fd: TcpHandle; millis: int): bool =
  ## Bound blocking writes. Pass 0 to restore platform blocking behavior.
  setTcpMillisOpt(fd, SO_SNDTIMEO, millis)

proc setTcpTimeoutMillis*(fd: TcpHandle; millis: int): bool =
  ## Apply the same timeout to both reads and writes.
  if not setTcpReadTimeoutMillis(fd, millis):
    return false
  setTcpWriteTimeoutMillis(fd, millis)

proc shutdownTcpRead*(fd: TcpHandle): bool =
  ## Forbid further receives on the socket while keeping the handle open.
  if fd == InvalidTcpHandle:
    return false
  when defined(windows):
    result = shutdownSocket(fd, SD_RECEIVE) == 0
  else:
    result = shutdownSocket(fd, SHUT_RD) == 0

proc shutdownTcpWrite*(fd: TcpHandle): bool =
  ## Send EOF to the peer while keeping the receive side open.
  if fd == InvalidTcpHandle:
    return false
  when defined(windows):
    result = shutdownSocket(fd, SD_SEND) == 0
  else:
    result = shutdownSocket(fd, SHUT_WR) == 0

proc shutdownTcpBoth*(fd: TcpHandle): bool =
  ## Forbid further sends and receives while keeping close ownership explicit.
  if fd == InvalidTcpHandle:
    return false
  when defined(windows):
    result = shutdownSocket(fd, SD_BOTH) == 0
  else:
    result = shutdownSocket(fd, SHUT_RDWR) == 0

proc connectTcp4*(hostOrderAddr: uint32; port: int): TcpHandle =
  ## Connect to an IPv4 address encoded in host byte order.
  let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
  if fd == InvalidTcpHandle:
    return InvalidTcpHandle

  var addr4 = default(SockaddrIn)
  addr4.sin_family = cushort(AF_INET)
  addr4.sin_port = htons(cushort(port))
  addr4.sin_addr.s_addr = htonl(hostOrderAddr)

  when defined(windows):
    if connectSocket(fd, cast[ptr SockAddr](addr addr4), cint(sizeof(addr4))) != 0:
      discard closeSocket(fd)
      return InvalidTcpHandle
  else:
    if connectSocket(fd, cast[ptr SockAddr](addr addr4), SockLen(sizeof(addr4))) != 0:
      discard closeSocket(fd)
      return InvalidTcpHandle
  return fd

proc connectTcp4NonBlocking*(hostOrderAddr: uint32; port: int): TcpConnectResult =
  ## Start a nonblocking IPv4 connect. Poll for writability, then call `finishTcpConnect`.
  let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
  if fd == InvalidTcpHandle:
    return TcpConnectResult(handle: InvalidTcpHandle, status: tcpConnectFailed, errorCode: lastTcpErrorCode())
  if not setTcpNonBlocking(fd):
    let code = lastTcpErrorCode()
    discard closeSocket(fd)
    return TcpConnectResult(handle: InvalidTcpHandle, status: tcpConnectFailed, errorCode: code)

  var addr4 = default(SockaddrIn)
  addr4.sin_family = cushort(AF_INET)
  addr4.sin_port = htons(cushort(port))
  addr4.sin_addr.s_addr = htonl(hostOrderAddr)

  when defined(windows):
    if connectSocket(fd, cast[ptr SockAddr](addr addr4), cint(sizeof(addr4))) != 0:
      let code = lastTcpErrorCode()
      if tcpErrorWouldRetry(code):
        return TcpConnectResult(handle: fd, status: tcpConnectInProgress, errorCode: code)
      else:
        discard closeSocket(fd)
        return TcpConnectResult(handle: InvalidTcpHandle, status: tcpConnectFailed, errorCode: code)
  else:
    if connectSocket(fd, cast[ptr SockAddr](addr addr4), SockLen(sizeof(addr4))) != 0:
      let code = lastTcpErrorCode()
      if tcpErrorWouldRetry(code):
        return TcpConnectResult(handle: fd, status: tcpConnectInProgress, errorCode: code)
      else:
        discard closeSocket(fd)
        return TcpConnectResult(handle: InvalidTcpHandle, status: tcpConnectFailed, errorCode: code)
  TcpConnectResult(handle: fd, status: tcpConnectConnected, errorCode: 0)

proc connectLocalhostTcp*(port: int): TcpHandle =
  connectTcp4(0x7f000001'u32, port)

proc connectLocalhostTcpNonBlocking*(port: int): TcpConnectResult =
  connectTcp4NonBlocking(0x7f000001'u32, port)

proc resolveTcp4*(host: string; dest: var uint32): bool =
  ## Resolve the first IPv4 address for `host` into host byte order.
  if host.len == 0:
    return false
  var query = host
  var resolved: AddrInfoPtr = nil
  if getaddrinfo(query.toCString(), nil, nil, addr resolved) != 0:
    return false
  var item = resolved
  while item != nil:
    if item[].ai_family == AF_INET and item[].ai_addr != nil:
      let addr4 = cast[ptr SockaddrIn](item[].ai_addr)
      dest = ntohl(addr4[].sin_addr.s_addr)
      freeaddrinfo(resolved)
      return true
    item = item[].ai_next
  freeaddrinfo(resolved)
  false

proc acceptTcpWithPeer*(listenFd: TcpHandle; peer: var TcpEndpoint): TcpHandle =
  var addr4 = default(SockaddrIn)
  when defined(windows):
    var addrLen = cint(sizeof(addr4))
    result = acceptSocket(listenFd, cast[ptr SockAddr](addr addr4), addr addrLen)
  else:
    var addrLen = SockLen(sizeof(addr4))
    result = acceptSocket(listenFd, cast[ptr SockAddr](addr addr4), addr addrLen)
  if result == InvalidTcpHandle:
    peer = invalidTcpEndpoint()
  else:
    peer = endpointFromSockaddr(addr4)

proc acceptTcp*(listenFd: TcpHandle): TcpHandle =
  var peer = invalidTcpEndpoint()
  acceptTcpWithPeer(listenFd, peer)

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
