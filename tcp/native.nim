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
    # IPv6 sockaddr. Only the scalar fields are declared; the 16 address bytes
    # live at byte offset 8 (family 2 + port 2 + flowinfo 4) and are read by
    # pointer offset in `endpointFromStorage`, avoiding the s6_addr union macro.
    Sockaddr_in6 {.importc: "struct sockaddr_in6", header: "<ws2tcpip.h>".} = object
      sin6_family*: cushort
      sin6_port*: cushort
      sin6_flowinfo*: uint32
      sin6_scope_id*: uint32
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
    # Non-self-referential hints view; see the posix branch for rationale.
    AddrInfoHints {.importc: "struct addrinfo", header: "<ws2tcpip.h>".} = object
      ai_flags*: cint
      ai_family*: cint
      ai_socktype*: cint
      ai_protocol*: cint
      ai_addrlen*: csize_t
      ai_canonname*: nil pointer
      ai_addr*: nil pointer
      ai_next*: nil pointer
    PollFd {.importc: "WSAPOLLFD", header: "<winsock2.h>".} = object
      fd*: TcpHandle
      events*: cshort
      revents*: cshort
    Linger {.importc: "struct linger", header: "<winsock2.h>".} = object
      l_onoff*: cushort
      l_linger*: cushort

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

    TcpAddressFamily* = enum
      tcpFamilyV4,
      tcpFamilyV6

    TcpEndpoint* = object
      family*: TcpAddressFamily
      address*: uint32           ## host-order IPv4, valid when family == tcpFamilyV4
      v6*: array[16, byte]       ## network-order 16 bytes, valid when family == tcpFamilyV6
      scopeId*: uint32           ## IPv6 zone/scope id (v6 only)
      port*: int

    TcpConnectResult* = object
      handle*: TcpHandle
      status*: TcpConnectStatus
      errorCode*: int

  const
    InvalidTcpHandle* = not 0'u
    AF_INET = 2.cint
    AF_INET6 = 23.cint            # Winsock AF_INET6
    IPPROTO_IPV6 = 41.cint
    IPV6_V6ONLY = 27.cint         # Winsock IPV6_V6ONLY
    AI_PASSIVE = 0x00000001.cint
    SOCK_STREAM = 1.cint
    IPPROTO_TCP = 6.cint
    SOL_SOCKET = 0xffff.cint
    SO_REUSEADDR = 4.cint
    SO_KEEPALIVE = 8.cint
    SO_BROADCAST = 0x0020.cint
    SO_LINGER = 0x0080.cint
    SO_SNDBUF = 0x1001.cint
    SO_RCVBUF = 0x1002.cint
    SO_SNDTIMEO = 0x1005.cint
    SO_RCVTIMEO = 0x1006.cint
    SO_ERROR = 0x1007.cint
    TCP_NODELAY = 1.cint
    SD_RECEIVE = 0.cint
    SD_SEND = 1.cint
    SD_BOTH = 2.cint
    FIONBIO = 0x8004667e.clong
    # Winsock does not raise SIGPIPE; there is no MSG_NOSIGNAL, so send() uses 0.
    MSG_NOSIGNAL = 0.cint
    # WSAPOLLFD event/revent flags, per <winsock2.h>. These match the documented
    # Winsock values and are intentionally different from the POSIX <poll.h> bits:
    #   POLLRDNORM 0x0100, POLLRDBAND 0x0200, POLLIN = RDNORM|RDBAND = 0x0300,
    #   POLLWRNORM/POLLOUT 0x0010, POLLERR 0x0001, POLLHUP 0x0002, POLLNVAL 0x0004.
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
    # IPv6 sockaddr. Only the scalar fields are declared; the 16 address bytes
    # live at byte offset 8 (family 2 + port 2 + flowinfo 4) and are read by
    # pointer offset in `endpointFromStorage`, avoiding the s6_addr union macro.
    Sockaddr_in6 {.importc: "struct sockaddr_in6", header: "<netinet/in.h>".} = object
      sin6_family*: cushort
      sin6_port*: cushort
      sin6_flowinfo*: uint32
      sin6_scope_id*: uint32
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
    # A non-self-referential view of the same `struct addrinfo`, used only to
    # build a zeroable getaddrinfo `hints` (the real AddrInfo can't be
    # `default()`-ed because it points at itself). Cast to AddrInfoPtr on use.
    AddrInfoHints {.importc: "struct addrinfo", header: "<netdb.h>".} = object
      ai_flags*: cint
      ai_family*: cint
      ai_socktype*: cint
      ai_protocol*: cint
      ai_addrlen*: SockLen
      ai_addr*: nil pointer
      ai_canonname*: nil pointer
      ai_next*: nil pointer
    PollFd {.importc: "struct pollfd", header: "<poll.h>".} = object
      fd*: cint
      events*: cshort
      revents*: cshort
    TimeVal {.importc: "struct timeval", header: "<sys/time.h>".} = object
      tv_sec*: clong
      tv_usec*: clong
    Linger {.importc: "struct linger", header: "<sys/socket.h>".} = object
      l_onoff*: cint
      l_linger*: cint

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

    TcpAddressFamily* = enum
      tcpFamilyV4,
      tcpFamilyV6

    TcpEndpoint* = object
      family*: TcpAddressFamily
      address*: uint32           ## host-order IPv4, valid when family == tcpFamilyV4
      v6*: array[16, byte]       ## network-order 16 bytes, valid when family == tcpFamilyV6
      scopeId*: uint32           ## IPv6 zone/scope id (v6 only)
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
  var SO_BROADCAST {.importc: "SO_BROADCAST", header: "<sys/socket.h>".}: cint
  var SO_LINGER {.importc: "SO_LINGER", header: "<sys/socket.h>".}: cint
  var SO_RCVBUF {.importc: "SO_RCVBUF", header: "<sys/socket.h>".}: cint
  var SO_SNDBUF {.importc: "SO_SNDBUF", header: "<sys/socket.h>".}: cint
  var SO_REUSEPORT {.importc: "SO_REUSEPORT", header: "<sys/socket.h>".}: cint
  # MSG_NOSIGNAL suppresses SIGPIPE on send() to a broken pipe (Linux/BSD).
  # macOS lacks the flag (it uses the SO_NOSIGPIPE sockopt instead), so fall
  # back to 0 there to keep this branch compiling.
  when defined(macosx):
    const MSG_NOSIGNAL = 0.cint
  else:
    var MSG_NOSIGNAL {.importc: "MSG_NOSIGNAL", header: "<sys/socket.h>".}: cint
  var F_GETFL {.importc: "F_GETFL", header: "<fcntl.h>".}: cint
  var F_SETFL {.importc: "F_SETFL", header: "<fcntl.h>".}: cint
  var O_NONBLOCK {.importc: "O_NONBLOCK", header: "<fcntl.h>".}: cint
  # IPv6 / dual-stack.
  var AF_INET6 {.importc: "AF_INET6", header: "<sys/socket.h>".}: cint
  var IPPROTO_IPV6 {.importc: "IPPROTO_IPV6", header: "<netinet/in.h>".}: cint
  var IPV6_V6ONLY {.importc: "IPV6_V6ONLY", header: "<netinet/in.h>".}: cint
  var AI_PASSIVE {.importc: "AI_PASSIVE", header: "<netdb.h>".}: cint

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

proc appendOctet(s: var string; value: uint32) =
  ## Append the decimal digits of a single 0..255 octet.
  let v = value and 0xff'u32
  if v >= 100'u32:
    s.add(char(ord('0') + int(v div 100'u32)))
    s.add(char(ord('0') + int((v div 10'u32) mod 10'u32)))
    s.add(char(ord('0') + int(v mod 10'u32)))
  elif v >= 10'u32:
    s.add(char(ord('0') + int(v div 10'u32)))
    s.add(char(ord('0') + int(v mod 10'u32)))
  else:
    s.add(char(ord('0') + int(v)))

proc formatIpv4*(address: uint32): string =
  ## Format a host-order IPv4 address as dotted-decimal text "a.b.c.d".
  ## The high byte is the first octet, e.g. 0x7f000001 -> "127.0.0.1".
  result = ""
  appendOctet(result, (address shr 24) and 0xff'u32)
  result.add('.')
  appendOctet(result, (address shr 16) and 0xff'u32)
  result.add('.')
  appendOctet(result, (address shr 8) and 0xff'u32)
  result.add('.')
  appendOctet(result, address and 0xff'u32)

proc parseIpv4Text*(s: string; dest: var uint32): bool =
  ## Parse dotted-decimal IPv4 text into a host-order uint32 (inverse of
  ## `formatIpv4`). Char-walked and range-checked: rejects octets > 255,
  ## empty octets, non-digits, and anything other than exactly four octets.
  var value: uint32 = 0
  var octetCount = 0
  var acc: uint32 = 0
  var digits = 0
  var i = 0
  while i < s.len:
    let c = s[i]
    if c == '.':
      if digits == 0:
        return false            # empty octet, e.g. "1..2.3"
      if octetCount >= 3:
        return false            # too many dots
      value = (value shl 8) or acc
      octetCount = octetCount + 1
      acc = 0
      digits = 0
    elif c >= '0' and c <= '9':
      acc = acc * 10'u32 + uint32(ord(c) - ord('0'))
      if acc > 255'u32:
        return false            # octet out of range
      digits = digits + 1
    else:
      return false              # invalid character
    i = i + 1
  if octetCount != 3 or digits == 0:
    return false                # need exactly four non-empty octets
  value = (value shl 8) or acc
  dest = value
  true

proc appendHex16(s: var string; value: uint) =
  ## Append a 16-bit group as lowercase hex with no leading zeros (RFC 5952).
  const digits = "0123456789abcdef"
  if value == 0'u:
    s.add('0')
    return
  var started = false
  var shift = 12
  while shift >= 0:
    let nib = int((value shr uint(shift)) and 0xf'u)
    if nib != 0 or started:
      s.add(digits[nib])
      started = true
    shift = shift - 4

proc formatIpv6*(a: array[16, byte]): string =
  ## Format 16 IPv6 address bytes as RFC 5952 canonical text: lowercase hex,
  ## no leading zeros per group, the single longest run of >= 2 zero groups
  ## compressed to "::" (leftmost on a tie). IPv4-mapped addresses
  ## (`::ffff:a.b.c.d`) render with a dotted-quad tail.
  # IPv4-mapped: first 10 bytes zero, bytes 10..11 == 0xff.
  var mapped = true
  var m = 0
  while m < 10:
    if a[m] != 0'u8:
      mapped = false
      break
    inc m
  if mapped and a[10] == 0xff'u8 and a[11] == 0xff'u8:
    result = "::ffff:"
    appendOctet(result, uint32(a[12]))
    result.add('.')
    appendOctet(result, uint32(a[13]))
    result.add('.')
    appendOctet(result, uint32(a[14]))
    result.add('.')
    appendOctet(result, uint32(a[15]))
    return result

  var g = default(array[8, uint])
  var i = 0
  while i < 8:
    g[i] = (uint(a[2 * i]) shl 8) or uint(a[2 * i + 1])
    inc i

  # Longest run of consecutive zero groups.
  var bestStart = -1
  var bestLen = 0
  var curStart = -1
  var curLen = 0
  i = 0
  while i < 8:
    if g[i] == 0'u:
      if curStart < 0:
        curStart = i
        curLen = 1
      else:
        curLen = curLen + 1
      if curLen > bestLen:
        bestLen = curLen
        bestStart = curStart
    else:
      curStart = -1
      curLen = 0
    inc i
  if bestLen < 2:
    bestStart = -1

  result = ""
  if bestStart < 0:
    i = 0
    while i < 8:
      if i > 0:
        result.add(':')
      appendHex16(result, g[i])
      inc i
  else:
    i = 0
    while i < bestStart:
      if i > 0:
        result.add(':')
      appendHex16(result, g[i])
      inc i
    result.add("::")
    i = bestStart + bestLen
    var first = true
    while i < 8:
      if not first:
        result.add(':')
      appendHex16(result, g[i])
      first = false
      inc i

proc parseIpv4Range(s: string; lo, hi: int; dest: var uint32): bool =
  ## Parse dotted-decimal IPv4 over the half-open range [lo, hi) into host order.
  var value: uint32 = 0
  var octetCount = 0
  var acc: uint32 = 0
  var digits = 0
  var i = lo
  while i < hi:
    let c = s[i]
    if c == '.':
      if digits == 0:
        return false
      if octetCount >= 3:
        return false
      value = (value shl 8) or acc
      octetCount = octetCount + 1
      acc = 0
      digits = 0
    elif c >= '0' and c <= '9':
      acc = acc * 10'u32 + uint32(ord(c) - ord('0'))
      if acc > 255'u32:
        return false
      digits = digits + 1
    else:
      return false
    inc i
  if octetCount != 3 or digits == 0:
    return false
  value = (value shl 8) or acc
  dest = value
  true

proc parseV6Side(s: string; lo, hi: int; groups: var array[8, int]; count: var int): bool =
  ## Parse one colon-separated side of an IPv6 literal over [lo, hi) into 16-bit
  ## groups. The final segment may be an embedded IPv4 dotted quad (2 groups).
  count = 0
  if lo >= hi:
    return true
  var i = lo
  while i < hi:
    let segStart = i
    var isV4 = false
    while i < hi and s[i] != ':':
      if s[i] == '.':
        isV4 = true
      inc i
    if segStart == i:
      return false            # empty segment (e.g. stray ':')
    if isV4:
      if i < hi:
        return false          # embedded IPv4 must be the last segment
      var v4: uint32 = 0
      if not parseIpv4Range(s, segStart, i, v4):
        return false
      if count > 6:
        return false
      groups[count] = int((v4 shr 16) and 0xffff'u32)
      inc count
      groups[count] = int(v4 and 0xffff'u32)
      inc count
    else:
      var val = 0
      var d = 0
      var j = segStart
      while j < i:
        let c = s[j]
        var hv = 0
        if c >= '0' and c <= '9':
          hv = ord(c) - ord('0')
        elif c >= 'a' and c <= 'f':
          hv = ord(c) - ord('a') + 10
        elif c >= 'A' and c <= 'F':
          hv = ord(c) - ord('A') + 10
        else:
          return false
        val = val * 16 + hv
        inc d
        if d > 4:
          return false        # more than 4 hex digits in a group
        inc j
      if count >= 8:
        return false
      groups[count] = val
      inc count
    if i < hi:
      inc i                   # consume the ':' separator
      if i >= hi:
        return false          # a bare trailing ':' is invalid here
  true

proc parseIpv6Text*(s: string): tuple[ok: bool, bytes: array[16, byte]] =
  ## Parse IPv6 text into 16 address bytes. Accepts the full 8-group form, the
  ## "::" zero-compressed form (at most once), and a trailing IPv4 dotted quad
  ## (e.g. "::ffff:1.2.3.4"). Char-walked; never slices. On failure `ok` is
  ## false and the bytes are all zero.
  var bytes = default(array[16, byte])
  if s.len == 0:
    return (false, bytes)

  # Locate a single "::" (zero-run compression marker).
  var dc = -1
  var i = 0
  while i + 1 < s.len:
    if s[i] == ':' and s[i + 1] == ':':
      dc = i
      break
    inc i

  var before = default(array[8, int])
  var nBefore = 0
  var after = default(array[8, int])
  var nAfter = 0
  var groups = default(array[8, int])

  if dc >= 0:
    # A second "::" would leave an empty segment on one side -> rejected there.
    if not parseV6Side(s, 0, dc, before, nBefore):
      return (false, bytes)
    if not parseV6Side(s, dc + 2, s.len, after, nAfter):
      return (false, bytes)
    if nBefore + nAfter > 7:   # "::" must compress at least one zero group
      return (false, bytes)
    var k = 0
    while k < nBefore:
      groups[k] = before[k]
      inc k
    let zeros = 8 - nBefore - nAfter
    k = 0
    while k < nAfter:
      groups[nBefore + zeros + k] = after[k]
      inc k
  else:
    if not parseV6Side(s, 0, s.len, before, nBefore):
      return (false, bytes)
    if nBefore != 8:
      return (false, bytes)
    var k = 0
    while k < 8:
      groups[k] = before[k]
      inc k

  var k = 0
  while k < 8:
    bytes[2 * k] = uint8((groups[k] shr 8) and 0xff)
    bytes[2 * k + 1] = uint8(groups[k] and 0xff)
    inc k
  (true, bytes)

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
    family: tcpFamilyV4,
    address: ntohl(addr4.sin_addr.s_addr),
    port: int(ntohs(addr4.sin_port))
  )

proc endpointFromStorage(storagePtr: pointer): TcpEndpoint =
  ## Decode a filled `sockaddr_storage` into a family-carrying `TcpEndpoint`.
  ## Branches on the address family: IPv6 (AF_INET6) reads the 16 address bytes
  ## from byte offset 8 plus the scope id; anything else is treated as IPv4.
  let fam = cast[ptr cushort](storagePtr)[]
  if fam == cushort(AF_INET6):
    var ep = default(TcpEndpoint)
    ep.family = tcpFamilyV6
    let sin6 = cast[ptr Sockaddr_in6](storagePtr)
    ep.port = int(ntohs(sin6[].sin6_port))
    ep.scopeId = sin6[].sin6_scope_id
    let base = cast[uint](storagePtr)
    var i = 0
    while i < 16:
      ep.v6[i] = cast[ptr uint8](base + 8'u + uint(i))[]
      inc i
    return ep
  else:
    let sin = cast[ptr SockaddrIn](storagePtr)
    return TcpEndpoint(
      family: tcpFamilyV4,
      address: ntohl(sin[].sin_addr.s_addr),
      port: int(ntohs(sin[].sin_port))
    )

proc localTcpEndpoint*(fd: TcpHandle): TcpEndpoint =
  ## Return the socket's bound address and port (IPv4 or IPv6), or an invalid
  ## endpoint. Reads into a `sockaddr_storage`-sized buffer and branches on the
  ## reported family, so a v6 socket yields a v6 endpoint.
  if fd == InvalidTcpHandle:
    return invalidTcpEndpoint()
  var storage = default(array[16, uint64])   # 128 bytes, 8-byte aligned
  when defined(windows):
    var addrLen = cint(sizeof(storage))
    if getsockname(fd, cast[ptr SockAddr](addr storage[0]), addr addrLen) != 0:
      return invalidTcpEndpoint()
  else:
    var addrLen = SockLen(sizeof(storage))
    if getsockname(fd, cast[ptr SockAddr](addr storage[0]), addr addrLen) != 0:
      return invalidTcpEndpoint()
  endpointFromStorage(cast[pointer](addr storage[0]))

proc peerTcpEndpoint*(fd: TcpHandle): TcpEndpoint =
  ## Return the connected peer's address and port (IPv4 or IPv6), or an invalid
  ## endpoint. Family-aware, mirroring `localTcpEndpoint`.
  if fd == InvalidTcpHandle:
    return invalidTcpEndpoint()
  var storage = default(array[16, uint64])   # 128 bytes, 8-byte aligned
  when defined(windows):
    var addrLen = cint(sizeof(storage))
    if getpeername(fd, cast[ptr SockAddr](addr storage[0]), addr addrLen) != 0:
      return invalidTcpEndpoint()
  else:
    var addrLen = SockLen(sizeof(storage))
    if getpeername(fd, cast[ptr SockAddr](addr storage[0]), addr addrLen) != 0:
      return invalidTcpEndpoint()
  endpointFromStorage(cast[pointer](addr storage[0]))

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

proc setTcpIntOpt(fd: TcpHandle; level, optname: cint; value: cint): bool =
  ## Set an integer-valued socket option, guarding an invalid handle.
  if fd == InvalidTcpHandle:
    return false
  var v = value
  when defined(windows):
    result = setsockopt(fd, level, optname, addr v, cint(sizeof(v))) == 0
  else:
    result = setsockopt(fd, level, optname, addr v, SockLen(sizeof(v))) == 0

proc setTcpReuseAddr*(fd: TcpHandle; enabled = true): bool =
  ## Allow binding to an address/port still in TIME_WAIT (SO_REUSEADDR).
  setTcpBoolOpt(fd, SOL_SOCKET, SO_REUSEADDR, enabled)

proc setTcpReusePort*(fd: TcpHandle; enabled = true): bool =
  ## Allow multiple sockets to bind the same port (SO_REUSEPORT). Unsupported
  ## on Windows, where it returns false.
  when defined(windows):
    result = false
  else:
    result = setTcpBoolOpt(fd, SOL_SOCKET, SO_REUSEPORT, enabled)

proc setTcpBroadcast*(fd: TcpHandle; enabled = true): bool =
  ## Permit sending to a broadcast address (SO_BROADCAST).
  setTcpBoolOpt(fd, SOL_SOCKET, SO_BROADCAST, enabled)

proc setTcpLinger*(fd: TcpHandle; onoff: bool; seconds: int): bool =
  ## Configure SO_LINGER. When `onoff` is true, close() blocks up to `seconds`
  ## for unsent data to flush; when false, linger is disabled.
  if fd == InvalidTcpHandle or seconds < 0:
    return false
  var value = default(Linger)
  when defined(windows):
    if onoff:
      value.l_onoff = 1.cushort
    else:
      value.l_onoff = 0.cushort
    value.l_linger = cushort(seconds)
    result = setsockopt(fd, SOL_SOCKET, SO_LINGER, addr value, cint(sizeof(value))) == 0
  else:
    if onoff:
      value.l_onoff = 1.cint
    else:
      value.l_onoff = 0.cint
    value.l_linger = cint(seconds)
    result = setsockopt(fd, SOL_SOCKET, SO_LINGER, addr value, SockLen(sizeof(value))) == 0

proc setTcpRecvBufferSize*(fd: TcpHandle; bytes: int): bool =
  ## Request the socket receive buffer size (SO_RCVBUF).
  setTcpIntOpt(fd, SOL_SOCKET, SO_RCVBUF, bytes.cint)

proc setTcpSendBufferSize*(fd: TcpHandle; bytes: int): bool =
  ## Request the socket send buffer size (SO_SNDBUF).
  setTcpIntOpt(fd, SOL_SOCKET, SO_SNDBUF, bytes.cint)

proc setTcpOption*(fd: TcpHandle; level, optname: cint; intval: int): bool =
  ## Generic passthrough to set any integer-valued socket option.
  setTcpIntOpt(fd, level, optname, intval.cint)

proc getTcpOption*(fd: TcpHandle; level, optname: cint; dest: var cint): bool =
  ## Generic passthrough to read any integer-valued socket option.
  if fd == InvalidTcpHandle:
    return false
  var value: cint = 0
  when defined(windows):
    var valueLen = cint(sizeof(value))
    if getsockopt(fd, level, optname, addr value, addr valueLen) != 0:
      return false
  else:
    var valueLen = SockLen(sizeof(value))
    if getsockopt(fd, level, optname, addr value, addr valueLen) != 0:
      return false
  dest = value
  true

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

proc connectTcp4Timeout*(hostOrderAddr: uint32; port: int; timeoutMillis: int): TcpConnectResult =
  ## Blocking connect with a timeout, composed from the nonblocking connect and
  ## `pollTcp`. On success the returned handle is switched back to blocking mode.
  var res = connectTcp4NonBlocking(hostOrderAddr, port)
  if res.status == tcpConnectConnected:
    discard setTcpBlocking(res.handle, true)
    return res
  if res.status == tcpConnectFailed:
    return res
  # In progress: wait for the socket to become writable, then check SO_ERROR.
  if not waitTcpWritable(res.handle, timeoutMillis):
    discard closeSocket(res.handle)
    return TcpConnectResult(handle: InvalidTcpHandle, status: tcpConnectFailed,
                            errorCode: res.errorCode)
  var errorCode = 0
  if finishTcpConnect(res.handle, errorCode):
    discard setTcpBlocking(res.handle, true)
    return TcpConnectResult(handle: res.handle, status: tcpConnectConnected, errorCode: 0)
  discard closeSocket(res.handle)
  TcpConnectResult(handle: InvalidTcpHandle, status: tcpConnectFailed, errorCode: errorCode)

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

proc portToService(port: int): string =
  ## Decimal port as a service string for getaddrinfo (no slicing / itoa dep).
  if port <= 0:
    return "0"
  var v = port
  var digits = default(array[8, char])
  var n = 0
  while v > 0 and n < digits.len:
    digits[n] = char(ord('0') + (v mod 10))
    v = v div 10
    inc n
  result = ""
  var i = n - 1
  while i >= 0:
    result.add digits[i]
    dec i

proc connectAddrInfo(info: AddrInfoPtr): TcpHandle =
  ## Try each resolved address in turn (any family), returning the first that
  ## connects. The sockaddr from getaddrinfo is passed to `connect` opaquely, so
  ## this works for IPv4 (A) and IPv6 (AAAA) without any per-family struct.
  var item = info
  while item != nil:
    if item[].ai_addr != nil:
      let s = socket(item[].ai_family, item[].ai_socktype, item[].ai_protocol)
      if s != InvalidTcpHandle:
        when defined(windows):
          if connectSocket(s, item[].ai_addr, cint(item[].ai_addrlen)) == 0:
            return s
        else:
          if connectSocket(s, item[].ai_addr, item[].ai_addrlen) == 0:
            return s
        discard closeSocket(s)
    item = item[].ai_next
  return InvalidTcpHandle

proc connectHostTcp*(host: string; port: int): TcpHandle =
  ## Resolve `host` (IPv4 and/or IPv6) and connect to the first address that
  ## accepts. Family-agnostic: prefers whatever order the resolver returns
  ## (typically IPv6 first when available, then IPv4). Returns `InvalidTcpHandle`
  ## if resolution fails or no address connects.
  if host.len == 0:
    return InvalidTcpHandle
  var node = host
  var serv = portToService(port)
  var hints = default(AddrInfoHints)
  hints.ai_family = 0            # AF_UNSPEC: allow both IPv4 and IPv6
  hints.ai_socktype = SOCK_STREAM
  var resolved: AddrInfoPtr = nil
  if getaddrinfo(node.toCString(), serv.toCString(), cast[AddrInfoPtr](addr hints), addr resolved) != 0:
    return InvalidTcpHandle
  result = connectAddrInfo(resolved)
  freeaddrinfo(resolved)

proc listenTcp6*(port: int; backlog = 128; dualStack = true): TcpHandle =
  ## Listen on an IPv6 socket bound to the wildcard address. With `dualStack`
  ## (default) `IPV6_V6ONLY` is cleared so the same socket also accepts
  ## IPv4-mapped connections — one listener serving both families. Set
  ## `dualStack = false` for IPv6-only.
  var serv = portToService(port)
  var hints = default(AddrInfoHints)
  hints.ai_family = AF_INET6
  hints.ai_socktype = SOCK_STREAM
  hints.ai_flags = AI_PASSIVE
  var resolved: AddrInfoPtr = nil
  if getaddrinfo(nil, serv.toCString(), cast[AddrInfoPtr](addr hints), addr resolved) != 0:
    return InvalidTcpHandle
  var fd = InvalidTcpHandle
  var item = resolved
  while item != nil:
    let s = socket(item[].ai_family, item[].ai_socktype, item[].ai_protocol)
    if s != InvalidTcpHandle:
      var yes: cint = 1
      var v6only: cint = 0
      if not dualStack:
        v6only = 1
      when defined(windows):
        discard setsockopt(s, SOL_SOCKET, SO_REUSEADDR, addr yes, cint(sizeof(yes)))
        discard setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, addr v6only, cint(sizeof(v6only)))
        if bindSocket(s, item[].ai_addr, cint(item[].ai_addrlen)) == 0 and
           listenSocket(s, backlog.cint) == 0:
          fd = s
      else:
        discard setsockopt(s, SOL_SOCKET, SO_REUSEADDR, addr yes, SockLen(sizeof(yes)))
        discard setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, addr v6only, SockLen(sizeof(v6only)))
        if bindSocket(s, item[].ai_addr, item[].ai_addrlen) == 0 and
           listenSocket(s, backlog.cint) == 0:
          fd = s
      if fd != InvalidTcpHandle:
        break
      discard closeSocket(s)
    item = item[].ai_next
  freeaddrinfo(resolved)
  return fd

proc acceptTcpWithPeer*(listenFd: TcpHandle; peer: var TcpEndpoint): TcpHandle =
  var storage = default(array[16, uint64])   # 128 bytes, 8-byte aligned
  when defined(windows):
    var addrLen = cint(sizeof(storage))
    result = acceptSocket(listenFd, cast[ptr SockAddr](addr storage[0]), addr addrLen)
  else:
    var addrLen = SockLen(sizeof(storage))
    result = acceptSocket(listenFd, cast[ptr SockAddr](addr storage[0]), addr addrLen)
  if result == InvalidTcpHandle:
    peer = invalidTcpEndpoint()
  else:
    peer = endpointFromStorage(cast[pointer](addr storage[0]))

proc acceptTcp*(listenFd: TcpHandle): TcpHandle =
  var peer = invalidTcpEndpoint()
  acceptTcpWithPeer(listenFd, peer)

proc readTcp*(fd: TcpHandle; buf: pointer; len: int): int =
  when defined(windows):
    result = recvSocket(fd, buf, len.cint, 0).int
  else:
    result = recvSocket(fd, buf, len.csize_t, 0)

proc writeTcp*(fd: TcpHandle; buf: pointer; len: int): int =
  ## Write bytes from a caller-owned buffer. On Linux/BSD the send uses
  ## MSG_NOSIGNAL so a broken-pipe write returns EPIPE instead of killing the
  ## process with SIGPIPE. `writeAllTcp` inherits this via `writeTcp`.
  when defined(windows):
    result = sendSocket(fd, buf, len.cint, 0).int
  else:
    result = sendSocket(fd, buf, len.csize_t, MSG_NOSIGNAL)

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
