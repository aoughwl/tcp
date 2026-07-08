## ttcp_ipv6.nim — real IPv6 (and dual-stack) loopback over the family-agnostic
## client + IPv6 listener.
##
## Brings up a dual-stack IPv6 listener on an ephemeral port, then connects to it
## twice through `connectHostTcp`: once over IPv6 (`::1`) and once over IPv4
## (`127.0.0.1`, accepted as a v4-mapped connection). Each time it echoes a
## payload through the kernel to prove the byte path works for both families.

import std/syncio
import tcp

proc check(cond: bool; msg: string) =
  if not cond:
    echo "FAIL: ", msg
    quit(1)

proc roundtrip(listenFd: TcpHandle; host: string; port: int; tag: string) =
  let cfd = connectHostTcp(host, port)
  check(cfd != InvalidTcpHandle, "connect to " & host & " failed")
  let afd = acceptTcp(listenFd)
  check(afd != InvalidTcpHandle, "accept for " & host & " failed")

  var msg = tag & "\n"
  var sendBuf = default(array[64, char])
  var i = 0
  while i < msg.len:
    sendBuf[i] = msg[i]
    inc i
  check(writeAllTcp(cfd, addr sendBuf[0], msg.len) == msg.len, "client write failed")

  var recvBuf = default(array[64, char])
  let n = readTcp(afd, addr recvBuf[0], recvBuf.len)
  check(n == msg.len, "server read wrong length for " & host)
  var got = ""
  var k = 0
  while k < n:
    got.add recvBuf[k]
    inc k
  check(got == msg, "payload mismatch for " & host & ": '" & got & "'")

  closeTcp(cfd)
  closeTcp(afd)

proc main =
  initTcp()
  let l = listenTcp6(0, 128, true)
  check(l != InvalidTcpHandle, "listenTcp6 failed")
  let port = localTcpEndpoint(l).port
  check(port > 0, "no ephemeral port")

  roundtrip(l, "::1", port, "v6")
  roundtrip(l, "127.0.0.1", port, "v4mapped")

  closeTcp(l)
  shutdownTcp()
  echo "ttcp_ipv6: all checks passed (port ", port, ")"

main()
