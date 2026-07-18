## ttcp_ipv6text.nim — pure round-trip tests for the RFC 5952 IPv6 text helpers
## `formatIpv6` and `parseIpv6Text`. No sockets: this only exercises the
## char-walked formatter/parser over canonical vectors.

import std/syncio
import tcp

proc check(cond: bool; label: string) =
  if not cond:
    echo "FAIL: ", label
    quit(1)

proc bytesOf(groups: array[8, int]): array[16, byte] =
  result = default(array[16, byte])
  var i = 0
  while i < 8:
    result[2 * i] = uint8((groups[i] shr 8) and 0xff)
    result[2 * i + 1] = uint8(groups[i] and 0xff)
    inc i

proc eqBytes(a, b: array[16, byte]): bool =
  var i = 0
  while i < 16:
    if a[i] != b[i]:
      return false
    inc i
  true

proc roundtripText(text: string) =
  ## parse(text) must succeed and format back to the same canonical text.
  let p = parseIpv6Text(text)
  check(p.ok, "parse ok: " & text)
  let f = formatIpv6(p.bytes)
  check(f == text, "canonical round-trip: '" & text & "' -> '" & f & "'")

proc main() =
  # --- Canonical text round-trips (format . parse == identity) -----------
  roundtripText("::")                       # all zeros
  roundtripText("::1")                      # loopback
  roundtripText("2001:db8::1")              # a compressible middle run
  roundtripText("fe80::1")                  # leading group + trailing zeros
  roundtripText("2001:db8::1:0:0:1")        # leftmost of two equal runs compressed
  roundtripText("2001:db8::")               # trailing zero run
  roundtripText("1:2:3:4:5:6:7:8")          # full form, no zeros
  roundtripText("::ffff:1.2.3.4")           # IPv4-mapped, dotted-quad tail
  roundtripText("2001:db8:85a3::8a2e:370:7334")

  # --- Explicit byte vectors --------------------------------------------
  check(formatIpv6(bytesOf([0, 0, 0, 0, 0, 0, 0, 0])) == "::", "format all-zero")
  check(formatIpv6(bytesOf([0, 0, 0, 0, 0, 0, 0, 1])) == "::1", "format ::1")
  check(formatIpv6(bytesOf([0x2001, 0x0db8, 0, 0, 0, 0, 0, 1])) == "2001:db8::1",
        "format 2001:db8::1")
  # RFC 5952: leading zeros dropped, lowercase, leftmost longest run compressed.
  check(formatIpv6(bytesOf([0x2001, 0x0DB8, 0, 0, 0, 0, 0, 0])) == "2001:db8::",
        "format trailing run")

  # --- parse -> known bytes ---------------------------------------------
  block:
    let p = parseIpv6Text("2001:db8::1")
    check(p.ok, "parse 2001:db8::1")
    check(eqBytes(p.bytes, bytesOf([0x2001, 0x0db8, 0, 0, 0, 0, 0, 1])),
          "parse 2001:db8::1 bytes")
  block:
    let p = parseIpv6Text("::ffff:127.0.0.1")
    check(p.ok, "parse v4-mapped")
    check(eqBytes(p.bytes, bytesOf([0, 0, 0, 0, 0, 0xffff, 0x7f00, 0x0001])),
          "parse v4-mapped bytes")
    # And it canonicalizes to the dotted-quad form.
    check(formatIpv6(p.bytes) == "::ffff:127.0.0.1", "v4-mapped canonical")
  block:
    # Uppercase input parses; formatter always emits lowercase.
    let p = parseIpv6Text("2001:DB8::AB")
    check(p.ok, "parse uppercase")
    check(formatIpv6(p.bytes) == "2001:db8::ab", "uppercase -> lowercase")

  # --- Rejections --------------------------------------------------------
  check(not parseIpv6Text("").ok, "reject empty")
  check(not parseIpv6Text("1:2:3:4:5:6:7").ok, "reject too few groups")
  check(not parseIpv6Text("1:2:3:4:5:6:7:8:9").ok, "reject too many groups")
  check(not parseIpv6Text("1::2::3").ok, "reject double compression")
  check(not parseIpv6Text("12345::1").ok, "reject 5-hex-digit group")
  check(not parseIpv6Text("::gg").ok, "reject non-hex")
  check(not parseIpv6Text("1:2:3:4:5:6:7:8::").ok, "reject nothing-to-compress")

  echo "ttcp_ipv6text: all checks passed"

main()
