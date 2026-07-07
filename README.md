# tcp

Native blocking TCP primitives.

The package provides a small socket API suitable for building higher-level
network libraries:

```nim
import tcp

initTcp()
let listener = listenTcp(8080)
let client = acceptTcp(listener)
discard readTcp(client, buffer, bufferLen)
discard writeTcp(client, buffer, bytes)
closeTcp(client)
closeTcp(listener)
shutdownTcp()
```

## API

| symbol | role |
|--------|------|
| `TcpHandle` | native socket handle |
| `TcpEndpoint` | IPv4 address and port reported by the socket stack |
| `InvalidTcpHandle` | invalid socket sentinel |
| `isValidTcp` | socket handle validity check |
| `initTcp`, `shutdownTcp` | platform socket lifecycle |
| `lastTcpErrorCode` | last platform socket error code for the current thread |
| `TcpErrorKind`, `lastTcpErrorKind`, `classifyTcpErrorCode` | portable socket error classification |
| `tcpErrorWouldRetry`, `tcpErrorTimedOut`, `tcpErrorInterrupted`, `tcpErrorDisconnected` | common socket error predicates |
| `listenTcp`, `listenTcp4` | bind and listen on a TCP port |
| `connectTcp4`, `connectLocalhostTcp` | connect to an IPv4 peer |
| `resolveTcp4` | resolve a hostname to an IPv4 address |
| `acceptTcp` | accept one client |
| `invalidTcpEndpoint`, `localTcpEndpoint`, `peerTcpEndpoint` | endpoint introspection |
| `readTcp` | read bytes into a caller-owned buffer |
| `writeTcp` | write bytes from a caller-owned buffer |
| `writeAllTcp` | retry short writes until complete or error |
| `setTcpNoDelay`, `setTcpKeepAlive` | common TCP socket options |
| `setTcpReadTimeoutMillis`, `setTcpWriteTimeoutMillis`, `setTcpTimeoutMillis` | bound blocking socket I/O |
| `setTcpBlocking`, `setTcpNonBlocking` | switch socket blocking mode |
| `TcpPollRequest`, `TcpPollResult`, `pollTcp` | wait for socket readiness |
| `shutdownTcpRead`, `shutdownTcpWrite`, `shutdownTcpBoth` | half-close or fully shut down socket traffic |
| `closeTcp` | close a socket handle |

## Notes

* Blocking API by design.
* POSIX sockets on Unix-like systems.
* Winsock on Windows.
* No framework runtime and no C shim.

## License

MIT.
