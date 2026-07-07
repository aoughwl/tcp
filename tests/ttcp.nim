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
discard waitTcpReadable(h, 0)
discard waitTcpWritable(h, 0)
var socketError = 0
discard tcpSocketErrorCode(h, socketError)
discard tcpSocketErrorCode(h)
discard finishTcpConnect(h, socketError)
discard finishTcpConnect(h)
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
var peer = invalidTcpEndpoint()
discard acceptTcpWithPeer(h, peer)
let l4: proc(hostOrderAddr: uint32; port: int; backlog: int): TcpHandle = listenTcp4
let c4: proc(hostOrderAddr: uint32; port: int): TcpHandle = connectTcp4
let cl: proc(port: int): TcpHandle = connectLocalhostTcp
let nb4: proc(hostOrderAddr: uint32; port: int): TcpConnectResult = connectTcp4NonBlocking
let nbl: proc(port: int): TcpConnectResult = connectLocalhostTcpNonBlocking
discard l4 == nil
discard c4 == nil
discard cl == nil
discard nb4 == nil
discard nbl == nil
discard tcpConnectFailed
discard tcpConnectInProgress
discard tcpConnectConnected
let connectResult = TcpConnectResult(handle: h, status: tcpConnectFailed, errorCode: 0)
discard connectResult.handle
discard connectResult.status
discard connectResult.errorCode
