## ttcp.aowl — compile-time API smoke for tcp.

import ../tcp

var h = InvalidTcpHandle
discard h
discard isValidTcp(h)
discard sizeof(TcpHandle)
let c4: proc(hostOrderAddr: uint32; port: int): TcpHandle = connectTcp4
let cl: proc(port: int): TcpHandle = connectLocalhostTcp
discard c4 == nil
discard cl == nil
