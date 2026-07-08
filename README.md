# tcp

Native, blocking TCP primitives for [Nimony](https://github.com/nim-lang/nimony) —
the bottom layer of the `tcp → net → serve` stack. Binds directly to the platform
socket API (POSIX / Winsock), hands you raw `TcpHandle`s and caller-owned buffers,
and reports failures as **status codes**, not exceptions.

**📖 Full docs → [aoughwl.github.io/docs/net-stack](https://aoughwl.github.io/docs/net-stack)**

```nim
import tcp
```

IPv4 + blocking by default; nonblocking connect, `pollTcp` readiness, and
per-operation timeouts opt in on the same handle. `formatIpv4` / `parseIpv4Text` /
`resolveTcp4` cover addressing.
