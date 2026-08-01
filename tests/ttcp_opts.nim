## ttcp_opts.nim — the socket-option config record, checked against the socket.
##
## Every assertion here reads the option back off a real file descriptor rather
## than trusting the return value of the call that set it. A record that
## "applies successfully" while the kernel keeps its old value is exactly the
## failure this record exists to make impossible, so `applyTcpOpts` returning
## `ok` is never the property under test.

import std/syncio
import tcp

proc check(cond: bool; label: string) =
  if not cond:
    echo "FAIL: ", label
    quit(1)

proc main() =
  initTcp()

  # --- The merge rule, on its own ----------------------------------------
  # This is the scope ladder in miniature: process policy, then a server that
  # overrides one field, then a connection that overrides another.
  var process = defaultTcpOpts()
  process.noDelay = optOn
  process.recvBufferSize = 32768

  var server = defaultTcpOpts()
  server.recvBufferSize = 65536

  let merged = merge(process, server)
  check(merged.noDelay == optOn, "unset field inherits from base")
  check(merged.recvBufferSize == 65536, "set field overrides base")

  var conn = defaultTcpOpts()
  conn.noDelay = optOff
  let final = merge(merged, conn)
  check(final.noDelay == optOff,
        "optOff overrides optOn — an override can turn something off")
  check(final.recvBufferSize == 65536, "unrelated field survives a second merge")

  # optUnset must be distinguishable from optOff. If it were not, an empty
  # override record would silently disable everything it did not mention.
  check(optUnset != optOff, "unset is not off")
  check(defaultTcpOpts().noDelay == optUnset, "the empty record sets nothing")
  check(isEmpty(defaultTcpOpts()), "the empty record reports itself empty")
  check(not isEmpty(process), "a record with a field set is not empty")

  # --- The empty record is a verified no-op ------------------------------
  let probe = listenTcp4(0x7f000001'u32, 0)
  check(isValidTcp(probe), "probe listener created")
  let noop = applyTcpOpts(probe, defaultTcpOpts())
  check(noop.applied == 0, "empty record touched nothing")
  check(noop.failed == 0, "empty record failed at nothing")
  check(ok(noop), "empty record reports ok")
  closeTcp(probe)

  # --- A set field reaches the kernel ------------------------------------
  var opts = defaultListenerOpts()
  opts.noDelay = optOn
  opts.keepAlive = optOn
  var report = TcpOptsReport(applied: 0, failed: 0, firstFailure: "")
  let listener = listenTcpOpts(0x7f000001'u32, 0, opts, report)
  check(isValidTcp(listener), "listener from an explicit policy")
  check(ok(report), "policy applied cleanly: " & report.firstFailure)

  var value = 0
  check(getTcpOptionByName(listener, "reuseaddr", value), "read back reuseaddr")
  check(value != 0, "defaultListenerOpts really enables SO_REUSEADDR")
  check(getTcpOptionByName(listener, "keepalive", value), "read back keepalive")
  check(value != 0, "keepAlive: optOn reached the socket")
  check(getTcpOptionByName(listener, "nodelay", value), "read back nodelay")
  check(value != 0, "noDelay: optOn reached the socket")

  # --- The opt-out that was impossible before ----------------------------
  # SO_REUSEADDR used to be forced on every listener with no way to decline.
  var strict = defaultListenerOpts()
  strict.reuseAddr = optOff
  var strictReport = TcpOptsReport(applied: 0, failed: 0, firstFailure: "")
  let strictListener = listenTcpOpts(0x7f000001'u32, 0, strict, strictReport)
  check(isValidTcp(strictListener), "listener with reuseAddr off")
  check(getTcpOptionByName(strictListener, "reuseaddr", value), "read back reuseaddr")
  check(value == 0,
        "reuseAddr: optOff is honoured — the forced option now has an opt-out")

  # --- Buffer sizing through the record ----------------------------------
  # The kernel is free to round SO_RCVBUF, and Linux doubles it, so the
  # property is "it moved to at least what was asked for", not equality.
  var buffered = defaultClientOpts()
  buffered.recvBufferSize = 262144
  var bufReport = TcpOptsReport(applied: 0, failed: 0, firstFailure: "")
  let bufSock = listenTcpOpts(0x7f000001'u32, 0, buffered, bufReport)
  check(isValidTcp(bufSock), "socket with a sized receive buffer")
  check(getTcpOptionByName(bufSock, "rcvbuf", value), "read back rcvbuf")
  check(value >= 262144, "recvBufferSize reached the socket")
  closeTcp(bufSock)

  # --- Source-port selection, observed from the far end ------------------
  # `bindHost`/`bindPort` had no entry point at all before this record: there
  # was no way to choose the local address a connection came from. The
  # assertion is what the *peer* sees, not what we asked for.
  let acceptor = listenTcp4(0x7f000001'u32, 0)
  check(isValidTcp(acceptor), "acceptor created")
  let acceptorPort = localTcpEndpoint(acceptor).port
  check(acceptorPort > 0, "acceptor bound to an ephemeral port")

  let sourcePort = 39871
  var client = defaultClientOpts()
  client.bindHost = "127.0.0.1"
  client.bindPort = sourcePort
  client.reuseAddr = optOn        # so a repeat run is not blocked by TIME_WAIT
  var clientReport = TcpOptsReport(applied: 0, failed: 0, firstFailure: "")
  let clientSock = connectTcp4Opts(0x7f000001'u32, acceptorPort, client, clientReport)
  check(isValidTcp(clientSock),
        "connect with a bound source port: " & clientReport.firstFailure)

  let accepted = acceptTcp(acceptor)
  check(isValidTcp(accepted), "connection accepted")
  let peer = peerTcpEndpoint(accepted)
  check(peer.port == sourcePort,
        "the peer sees the source port the record asked for")

  closeTcp(accepted)
  closeTcp(clientSock)
  closeTcp(acceptor)

  # --- The escape hatch is reachable and honest --------------------------
  var level: cint = 0
  var optname: cint = 0
  check(tcpOptionByName("rcvbuf", level, optname), "known name resolves")
  check(not tcpOptionByName("no-such-option", level, optname),
        "an unknown name fails instead of resolving to option 0")
  check(setTcpOptionByName(listener, "sndbuf", 131072), "set by name")
  check(getTcpOptionByName(listener, "sndbuf", value), "get by name")
  check(value >= 131072, "the by-name setter reached the socket")
  check(not getTcpOptionByName(listener, "no-such-option", value),
        "an unknown name is refused by the getter too")

  # --- A failure is reported, not swallowed ------------------------------
  let closedReport = applyTcpOpts(InvalidTcpHandle, defaultListenerOpts())
  check(not ok(closedReport), "an invalid handle is a failure")
  check(closedReport.firstFailure.len > 0, "the failure is named")

  closeTcp(strictListener)
  closeTcp(listener)
  shutdownTcp()
  echo "ok"

main()
