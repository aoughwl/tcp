## ttcp.nim — compile-time API smoke for tcp.

import tcp

var h = InvalidTcpHandle
discard h
discard isValidTcp(h)
discard lastTcpErrorCode()
discard lastTcpErrorKind()
discard classifyTcpErrorCode(0)
discard tcpErrorWouldRetry(0)
discard tcpErrorTimedOut(0)
discard tcpErrorInterrupted(0)
discard tcpErrorDisconnected(0)
discard sizeof(TcpHandle)
discard setTcpNoDelay(h)
discard setTcpKeepAlive(h)
discard setTcpReadTimeoutMillis(h, 0)
discard setTcpWriteTimeoutMillis(h, 0)
discard setTcpTimeoutMillis(h, 0)
discard setTcpBlocking(h, true)
discard setTcpNonBlocking(h)
var pollRequest = TcpPollRequest(read: true, write: false)
var pollResult = default(TcpPollResult)
discard pollTcp(h, pollRequest, 0, pollResult)
discard shutdownTcpRead(h)
discard shutdownTcpWrite(h)
discard shutdownTcpBoth(h)
let endpoint = invalidTcpEndpoint()
discard endpoint.address
discard endpoint.port
discard localTcpEndpoint(h)
discard peerTcpEndpoint(h)
var resolved = 0'u32
discard resolveTcp4("localhost", resolved)
let l4: proc(hostOrderAddr: uint32; port: int; backlog: int): TcpHandle = listenTcp4
let c4: proc(hostOrderAddr: uint32; port: int): TcpHandle = connectTcp4
let cl: proc(port: int): TcpHandle = connectLocalhostTcp
discard l4 == nil
discard c4 == nil
discard cl == nil
