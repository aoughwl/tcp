# tcp

Native, blocking TCP primitives for [Nimony](https://github.com/nim-lang/nimony)
— the bottom layer of the `tcp → net → serve` stack. It binds directly to the
platform socket API (POSIX sockets on Unix, Winsock on Windows) with no C shim
and no framework runtime, hands you raw `TcpHandle`s and caller-owned buffers,
and reports failures as status codes and error kinds rather than exceptions.
IPv4 and blocking I/O are the defaults; nonblocking connect, readiness polling,
and millisecond timeouts are opt-in on the same handles.

## Contents

- [Motivation](#motivation)
- [API](#api)
- [Layout](#layout)
- [Design notes](#design-notes)
- [Limitations](#limitations)
- [Testing](#testing)
- [Requirements](#requirements)
- [License](#license)

## Motivation

Nim 2's `std/nativesockets` is the closest stdlib analogue, but it is Nim-2 code
and leans on exceptions, `Port`/`Domain` abstractions, and `getAddrInfo` plumbing
that Nimony does not want to inherit. `tcp` is a from-scratch, Nimony-native
substitute that keeps the surface small and the error model explicit:

| Problem with the Nim2 stdlib path | `tcp`'s approach |
|-----------------------------------|------------------|
| `nativesockets` raises `OSError` on failure | Every call returns a status/count; the last error is available as a code **and** a classified `TcpErrorKind`. |
| Address handling goes through `getAddrInfo`/`Sockaddr` unions | `formatIpv4` / `parseIpv4Text` and `connectTcp4` take a plain host-order `uint32`; `resolveTcp4` is the only DNS path. |
| Blocking vs. nonblocking is a socket-wide mode set once | Blocking is the default, but nonblocking connect, `pollTcp` readiness, and per-operation timeouts layer onto the same handle. |
| Buffers are stdlib strings/seqs the callee grows | Reads and writes take a caller-owned `pointer` + length; the library never allocates on your behalf. |

## API

Everything is re-exported from `import tcp`. Grouped by concern; ✅ marks the
current, tested surface.

### Lifecycle & handles

| Symbol | Role | |
|--------|------|---|
| `TcpHandle`, `InvalidTcpHandle`, `isValidTcp` | native socket handle + invalid sentinel + validity check | ✅ |
| `initTcp`, `shutdownTcp` | platform socket subsystem lifecycle (Winsock startup/teardown; no-op on POSIX) | ✅ |
| `closeTcp` | close a socket handle | ✅ |

### Addresses

| Symbol | Role | |
|--------|------|---|
| `formatIpv4` | host-order `uint32` → dotted-decimal text | ✅ |
| `parseIpv4Text` | dotted-decimal text → `uint32` (round-trips `formatIpv4`) | ✅ |
| `resolveTcp4` | resolve a hostname to an IPv4 address | ✅ |

### Errors

| Symbol | Role | |
|--------|------|---|
| `lastTcpErrorCode` | last platform error code for the current thread | ✅ |
| `TcpErrorKind`, `lastTcpErrorKind`, `classifyTcpErrorCode` | portable classification of a raw code | ✅ |
| `tcpErrorWouldRetry`, `tcpErrorTimedOut`, `tcpErrorInterrupted`, `tcpErrorDisconnected` | common error predicates | ✅ |

### Listen / connect / accept

| Symbol | Role | |
|--------|------|---|
| `listenTcp`, `listenTcp4` | bind and listen on a TCP port | ✅ |
| `connectTcp4`, `connectLocalhostTcp` | blocking connect to an IPv4 peer | ✅ |
| `connectTcp4Timeout` | blocking connect bounded by a millisecond timeout (nonblocking connect + poll) | ✅ |
| `connectTcp4NonBlocking`, `connectLocalhostTcpNonBlocking` | start a nonblocking connect | ✅ |
| `TcpConnectStatus`, `TcpConnectResult`, `finishTcpConnect`, `tcpSocketErrorCode` | inspect / complete a nonblocking connect | ✅ |
| `acceptTcp`, `acceptTcpWithPeer` | accept one client, optionally returning peer metadata | ✅ |

### Endpoints & I/O

| Symbol | Role | |
|--------|------|---|
| `TcpEndpoint`, `invalidTcpEndpoint`, `localTcpEndpoint`, `peerTcpEndpoint` | endpoint introspection | ✅ |
| `readTcp` | read bytes into a caller-owned buffer | ✅ |
| `writeTcp` | write bytes from a caller-owned buffer | ✅ |
| `writeAllTcp` | retry short writes until complete or error; suppresses `SIGPIPE` (`MSG_NOSIGNAL`) | ✅ |

### Socket options

| Symbol | Role | |
|--------|------|---|
| `setTcpNoDelay`, `setTcpKeepAlive` | common TCP options | ✅ |
| `setTcpReuseAddr`, `setTcpReusePort`, `setTcpBroadcast` | boolean options (`SO_REUSEPORT` is POSIX-only) | ✅ |
| `setTcpLinger` | configure `SO_LINGER` close behavior | ✅ |
| `setTcpRecvBufferSize`, `setTcpSendBufferSize` | request `SO_RCVBUF` / `SO_SNDBUF` sizes | ✅ |
| `setTcpOption`, `getTcpOption` | generic integer `getsockopt`/`setsockopt` passthrough | ✅ |

### Blocking mode, timeouts, readiness, shutdown

| Symbol | Role | |
|--------|------|---|
| `setTcpBlocking`, `setTcpNonBlocking` | switch blocking mode | ✅ |
| `setTcpReadTimeoutMillis`, `setTcpWriteTimeoutMillis`, `setTcpTimeoutMillis` | bound blocking socket I/O | ✅ |
| `TcpPollRequest`, `TcpPollResult`, `pollTcp` | wait for read/write readiness (or error/hangup) | ✅ |
| `waitTcpReadable`, `waitTcpWritable` | common single-socket readiness waits | ✅ |
| `shutdownTcpRead`, `shutdownTcpWrite`, `shutdownTcpBoth` | half-close or fully shut down traffic | ✅ |

```nim
import tcp

initTcp()
let listener = listenTcp(8080)
let client = acceptTcp(listener)

var buffer: array[4096, char]
let got = readTcp(client, addr buffer[0], buffer.len)
discard writeAllTcp(client, addr buffer[0], got)   # echo it back

closeTcp(client)
closeTcp(listener)
shutdownTcp()
```

## Layout

```
tcp/
├── tcp.nim             umbrella: imports and re-exports tcp/native
├── tcp/
│   └── native.nim      the whole implementation: platform importc bindings +
│                       the public procs (Windows/Winsock and POSIX branches)
├── tests/
│   ├── ttcp.nim        compile-time API smoke (every symbol referenced once)
│   └── ttcp_loopback.nim  real single-process loopback behavioral test
├── tcp.nimble
└── README.md
```

## Design notes

- **No C shim, no runtime.** `native.nim` `importc`s the platform structs and
  syscalls directly under `when defined(windows)` / else branches; there is no
  helper `.c` file and nothing links a framework runtime.
- **Caller-owned buffers.** `readTcp` / `writeTcp` / `writeAllTcp` take a raw
  `pointer` and a length. The library never allocates or resizes a buffer for
  you, so ownership and lifetime stay with the caller.
- **Status-based errors, not exceptions.** Failures surface as return codes plus
  a per-thread `lastTcpErrorCode`, which `classifyTcpErrorCode` folds into a
  portable `TcpErrorKind` and the `tcpError*` predicates. Nothing raises.
- **Blocking by default, async-ready.** A fresh handle is blocking; nonblocking
  connect, `pollTcp`, and the `*TimeoutMillis` setters opt in per handle without
  a separate socket type.
- **Signal-safe writes.** Writes pass `MSG_NOSIGNAL` where available so a peer
  reset does not deliver `SIGPIPE`.

## Limitations

These are the edges to close on the way to fully superseding the Nim2 stdlib:

- **IPv4 only** — no IPv6 (`AF_INET6`) addresses or endpoints.
- **TCP only** — no UDP/datagram sockets and no Unix-domain sockets.
- **No TLS/SSL** — plaintext transport only.
- Single-thread, blocking-first. Concurrency is left to the caller (nonblocking
  connect + `pollTcp` are the provided building blocks).

## Testing

Two tests: a compile-time smoke that references every exported symbol, and a
real loopback test that listens, does a nonblocking connect + `pollTcp` + accept
handshake on `127.0.0.1`, writes one way, reads the other, asserts the bytes
match, and round-trips `formatIpv4` / `parseIpv4Text`.

```bash
cd /home/savant/aoughwl-tcp
nimony c -r --path:/home/savant/aoughwl-tcp tests/ttcp_loopback.nim   # prints: ok
nimony c -r --path:/home/savant/aoughwl-tcp tests/ttcp.nim            # compiles clean
```

## Requirements

A built [Nimony](https://github.com/nim-lang/nimony) toolchain providing the
`nimony` compiler on `PATH` (e.g. `~/nimony/bin`). No third-party dependencies.

## License

MIT.
