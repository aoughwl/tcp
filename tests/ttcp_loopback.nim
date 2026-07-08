## ttcp_loopback.nim — real single-process loopback behavioral test.
##
## Exercises the actual socket path: listen, nonblocking connect, poll, accept,
## finish connect, write one way, read the other, and assert the bytes match.
## Also round-trips the formatIpv4 / parseIpv4Text helpers.

import std/syncio
import tcp

proc check(cond: bool; label: string) =
  if not cond:
    echo "FAIL: ", label
    quit(1)

proc main() =
  initTcp()

  # --- Address helpers ---------------------------------------------------
  check(formatIpv4(0x7f000001'u32) == "127.0.0.1", "formatIpv4 loopback")
  check(formatIpv4(0'u32) == "0.0.0.0", "formatIpv4 zero")
  check(formatIpv4(0xffffffff'u32) == "255.255.255.255", "formatIpv4 broadcast")
  check(formatIpv4(0x0a141e28'u32) == "10.20.30.40", "formatIpv4 mixed")

  var parsed = 0'u32
  check(parseIpv4Text("127.0.0.1", parsed), "parseIpv4Text ok")
  check(parsed == 0x7f000001'u32, "parseIpv4Text value")
  # Round-trip a handful of addresses.
  var rt = 0'u32
  check(parseIpv4Text(formatIpv4(0x0a141e28'u32), rt) and rt == 0x0a141e28'u32,
        "parseIpv4Text round-trip")
  # Rejections.
  var junk = 0'u32
  check(not parseIpv4Text("256.0.0.1", junk), "reject octet > 255")
  check(not parseIpv4Text("1.2.3", junk), "reject too few octets")
  check(not parseIpv4Text("1.2.3.4.5", junk), "reject too many octets")
  check(not parseIpv4Text("1..2.3", junk), "reject empty octet")
  check(not parseIpv4Text("1.2.3.", junk), "reject trailing dot")
  check(not parseIpv4Text("1.2.x.4", junk), "reject non-digit")
  check(not parseIpv4Text("", junk), "reject empty string")

  # --- Loopback data path ------------------------------------------------
  let port = 34567
  let listener = listenTcp4(0x7f000001'u32, port)
  check(isValidTcp(listener), "listener created")
  check(setTcpNonBlocking(listener), "listener nonblocking")

  # Exercise the broadened socket options on a real socket.
  check(setTcpReuseAddr(listener), "setTcpReuseAddr")
  check(setTcpRecvBufferSize(listener, 65536), "setTcpRecvBufferSize")

  # Start a nonblocking connect to the listener.
  let conn = connectTcp4NonBlocking(0x7f000001'u32, port)
  check(conn.status != tcpConnectFailed, "connect not failed")
  let client = conn.handle
  check(isValidTcp(client), "client handle valid")
  check(setTcpNoDelay(client), "setTcpNoDelay client")

  # Poll the listener until it is readable, then accept.
  check(waitTcpReadable(listener, 2000), "listener became readable")
  let server = acceptTcp(listener)
  check(isValidTcp(server), "accepted server socket")

  # Finish the client-side connect (poll writable first if still in progress).
  if conn.status == tcpConnectInProgress:
    check(waitTcpWritable(client, 2000), "client became writable")
  check(finishTcpConnect(client), "finishTcpConnect")

  # Write known bytes client -> server and read them back.
  var payload = "hello-loopback-42"
  let sent = writeAllTcp(client, payload.toCString(), payload.len)
  check(sent == payload.len, "writeAllTcp wrote all bytes")

  var buffer = default(array[64, char])
  var got = 0
  while got < payload.len:
    let n = readTcp(server, addr buffer[got], payload.len - got)
    check(n > 0, "readTcp made progress")
    got = got + n
  check(got == payload.len, "read expected byte count")

  var i = 0
  while i < payload.len:
    check(buffer[i] == payload[i], "byte matches at index")
    i = i + 1

  # Peer introspection should report the loopback address.
  let peer = peerTcpEndpoint(server)
  check(peer.address == 0x7f000001'u32, "peer address is loopback")

  # --- Teardown ----------------------------------------------------------
  closeTcp(client)
  closeTcp(server)
  closeTcp(listener)
  shutdownTcp()
  echo "ok"

main()
