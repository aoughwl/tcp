## tcp/tcpopts.nim — the socket-option config record.
##
## Every socket option in this library has always been reachable, but only as an
## imperative call against an already-created handle. That makes a policy
## impossible to *carry*: a caller three layers up (`net`, `serve`, the reactor)
## has no value it can pass down saying "listeners look like this". This module
## is that value.
##
## `TcpOpts` is a plain record of tri-state flags and sentinel-valued integers.
## Nothing in it means "the default" implicitly — `optUnset` / `TcpUnset` means
## *leave the socket alone*, so an all-unset record applied to a handle is a
## verified no-op. The values a library currently forces are not hidden in a
## call site any more; they are the readable fields of `defaultListenerOpts()`
## and `defaultClientOpts()`.
##
## This module deliberately imports nothing: it is the shared vocabulary that
## `native` (which applies it) and every consumer above (which composes it) can
## both depend on without a cycle.

type
  TriOpt* = enum
    ## A boolean that can also be absent. Absence is what makes merging work:
    ## an override record only overrides the fields it actually sets.
    optUnset,     ## leave whatever the socket already has
    optOff,       ## explicitly disable
    optOn         ## explicitly enable

const
  TcpUnset* = -1
    ## Sentinel for the integer fields. Every one of them is meaningfully
    ## non-negative, so -1 can never collide with a real value.

type
  TcpOpts* = object
    ## Declarative socket policy. Applied to a handle by `applyTcpOpts`, and
    ## honoured at creation time by the `*Opts` listen/connect entry points.
    noDelay*: TriOpt            ## TCP_NODELAY
    keepAlive*: TriOpt          ## SO_KEEPALIVE
    reuseAddr*: TriOpt          ## SO_REUSEADDR
    reusePort*: TriOpt          ## SO_REUSEPORT (POSIX only)
    broadcast*: TriOpt          ## SO_BROADCAST
    closeOnExec*: TriOpt        ## FD_CLOEXEC
    nonBlocking*: TriOpt        ## O_NONBLOCK / FIONBIO
    v6Only*: TriOpt             ## IPV6_V6ONLY; optOff means dual-stack
    linger*: TriOpt             ## SO_LINGER on/off
    lingerSeconds*: int         ## SO_LINGER timeout, used when linger == optOn
    recvBufferSize*: int        ## SO_RCVBUF
    sendBufferSize*: int        ## SO_SNDBUF
    readTimeoutMillis*: int     ## SO_RCVTIMEO
    writeTimeoutMillis*: int    ## SO_SNDTIMEO
    backlog*: int               ## listen(2) backlog
    bindDevice*: string         ## SO_BINDTODEVICE interface name; "" = unset
    bindHost*: string           ## local address to bind before connect; "" = unset
    bindPort*: int              ## local port to bind before connect

  TcpOptsReport* = object
    ## What `applyTcpOpts` actually managed to do. An option that the platform
    ## rejects is not silently swallowed: it is counted, and the first one is
    ## named, so a caller can log or fail on it.
    applied*: int
    failed*: int
    firstFailure*: string

proc defaultTcpOpts*(): TcpOpts =
  ## The empty policy: every field unset. Applying this to a socket changes
  ## nothing, which is the property that lets it be the base of every merge.
  TcpOpts(
    noDelay: optUnset, keepAlive: optUnset, reuseAddr: optUnset,
    reusePort: optUnset, broadcast: optUnset, closeOnExec: optUnset,
    nonBlocking: optUnset, v6Only: optUnset, linger: optUnset,
    lingerSeconds: TcpUnset, recvBufferSize: TcpUnset, sendBufferSize: TcpUnset,
    readTimeoutMillis: TcpUnset, writeTimeoutMillis: TcpUnset,
    backlog: TcpUnset, bindDevice: "", bindHost: "", bindPort: TcpUnset)

const
  DefaultBacklog* = 128
    ## What `listenTcp` has always passed. Named here so it can be seen.

proc defaultListenerOpts*(): TcpOpts =
  ## Exactly the policy `listenTcp4`/`listenTcp6` have always hardcoded —
  ## SO_REUSEADDR on, FD_CLOEXEC on, backlog 128, dual-stack for v6. Written out
  ## as data so it can be read, diffed, and overridden field by field rather
  ## than being three literals buried in a socket-setup sequence.
  result = defaultTcpOpts()
  result.reuseAddr = optOn
  result.closeOnExec = optOn
  result.v6Only = optOff
  result.backlog = DefaultBacklog

proc defaultClientOpts*(): TcpOpts =
  ## What the connect paths have always done: close-on-exec, nothing else.
  result = defaultTcpOpts()
  result.closeOnExec = optOn

proc merge*(base: TcpOpts; over: TcpOpts): TcpOpts =
  ## The scope-ladder rule, in one place: a field set in `over` wins, a field
  ## left unset in `over` inherits from `base`. Composing process -> server ->
  ## connection policy is repeated application of this.
  result = base
  if over.noDelay != optUnset: result.noDelay = over.noDelay
  if over.keepAlive != optUnset: result.keepAlive = over.keepAlive
  if over.reuseAddr != optUnset: result.reuseAddr = over.reuseAddr
  if over.reusePort != optUnset: result.reusePort = over.reusePort
  if over.broadcast != optUnset: result.broadcast = over.broadcast
  if over.closeOnExec != optUnset: result.closeOnExec = over.closeOnExec
  if over.nonBlocking != optUnset: result.nonBlocking = over.nonBlocking
  if over.v6Only != optUnset: result.v6Only = over.v6Only
  if over.linger != optUnset: result.linger = over.linger
  if over.lingerSeconds != TcpUnset: result.lingerSeconds = over.lingerSeconds
  if over.recvBufferSize != TcpUnset: result.recvBufferSize = over.recvBufferSize
  if over.sendBufferSize != TcpUnset: result.sendBufferSize = over.sendBufferSize
  if over.readTimeoutMillis != TcpUnset: result.readTimeoutMillis = over.readTimeoutMillis
  if over.writeTimeoutMillis != TcpUnset: result.writeTimeoutMillis = over.writeTimeoutMillis
  if over.backlog != TcpUnset: result.backlog = over.backlog
  if over.bindDevice.len > 0: result.bindDevice = over.bindDevice
  if over.bindHost.len > 0: result.bindHost = over.bindHost
  if over.bindPort != TcpUnset: result.bindPort = over.bindPort

proc backlogOr*(opts: TcpOpts; fallback = DefaultBacklog): int =
  ## The backlog to actually pass to `listen(2)`.
  if opts.backlog == TcpUnset: fallback else: opts.backlog

proc wantsDualStack*(opts: TcpOpts): bool =
  ## IPv6 listeners accept IPv4-mapped peers unless `v6Only` is explicitly on.
  opts.v6Only != optOn

proc isEmpty*(opts: TcpOpts): bool =
  ## True when applying this record would touch nothing.
  opts.noDelay == optUnset and opts.keepAlive == optUnset and
    opts.reuseAddr == optUnset and opts.reusePort == optUnset and
    opts.broadcast == optUnset and opts.closeOnExec == optUnset and
    opts.nonBlocking == optUnset and opts.linger == optUnset and
    opts.lingerSeconds == TcpUnset and opts.recvBufferSize == TcpUnset and
    opts.sendBufferSize == TcpUnset and opts.readTimeoutMillis == TcpUnset and
    opts.writeTimeoutMillis == TcpUnset and opts.bindDevice.len == 0

proc ok*(report: TcpOptsReport): bool =
  ## Every option the record asked for was accepted.
  report.failed == 0
