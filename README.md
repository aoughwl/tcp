# tcp

Native blocking TCP primitives for Nimony.

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
| `InvalidTcpHandle` | invalid socket sentinel |
| `isValidTcp` | socket handle validity check |
| `initTcp`, `shutdownTcp` | platform socket lifecycle |
| `listenTcp`, `listenTcp4` | bind and listen on a TCP port |
| `acceptTcp` | accept one client |
| `readTcp` | read bytes into a caller-owned buffer |
| `writeTcp` | write bytes from a caller-owned buffer |
| `writeAllTcp` | retry short writes until complete or error |
| `closeTcp` | close a socket handle |

## Notes

* Blocking API by design.
* POSIX sockets on Unix-like systems.
* Winsock on Windows.
* No framework runtime and no C shim.

## License

MIT.
