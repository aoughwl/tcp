## ttcp.aowl — compile-time API smoke for tcp.

import tcp

var h = InvalidTcpHandle
discard h
discard isValidTcp(h)
discard sizeof(TcpHandle)
