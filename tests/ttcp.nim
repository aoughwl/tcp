## ttcp.aowl — compile-time API smoke for tcp.

import tcp

var h = InvalidTcpHandle
discard h
discard isValidTcp(h)
discard sizeof(TcpHandle)
discard setTcpNoDelay(h)
discard setTcpKeepAlive(h)
discard shutdownTcpRead(h)
discard shutdownTcpWrite(h)
discard shutdownTcpBoth(h)
let l4: proc(hostOrderAddr: uint32; port: int; backlog: int): TcpHandle = listenTcp4
let c4: proc(hostOrderAddr: uint32; port: int): TcpHandle = connectTcp4
let cl: proc(port: int): TcpHandle = connectLocalhostTcp
discard l4 == nil
discard c4 == nil
discard cl == nil
