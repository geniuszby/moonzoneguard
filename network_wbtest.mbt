///|
test "ipv4 accepts ordinary dotted decimal" {
  assert_eq(valid_ipv4("0.0.0.0"), true)
  assert_eq(valid_ipv4("192.0.2.1"), true)
  assert_eq(valid_ipv4("255.255.255.255"), true)
}

///|
test "ipv4 rejects missing or extra octets" {
  assert_eq(valid_ipv4("192.0.2"), false)
  assert_eq(valid_ipv4("192.0.2.1.5"), false)
  assert_eq(valid_ipv4(""), false)
}

///|
test "ipv4 rejects out of range octets" {
  assert_eq(valid_ipv4("256.0.0.1"), false)
  assert_eq(valid_ipv4("192.0.2.999"), false)
  assert_eq(valid_ipv4("192.0.2.-1"), false)
}

///|
test "ipv4 rejects nondecimal content" {
  assert_eq(valid_ipv4("192.0.2.a"), false)
  assert_eq(valid_ipv4("192.0.2.1x"), false)
  assert_eq(valid_ipv4("192..2.1"), false)
}

///|
test "ipv6 accepts full eight-group address" {
  assert_eq(valid_ipv6("2001:0db8:0000:0000:0000:ff00:0042:8329"), true)
  assert_eq(valid_ipv6("0:0:0:0:0:0:0:1"), true)
}

///|
test "ipv6 accepts compressed addresses" {
  assert_eq(valid_ipv6("::"), true)
  assert_eq(valid_ipv6("::1"), true)
  assert_eq(valid_ipv6("2001:db8::1"), true)
  assert_eq(valid_ipv6("2001:db8:1:2:3:4:5::"), true)
}

///|
test "ipv6 accepts embedded ipv4 suffix" {
  assert_eq(valid_ipv6("::ffff:192.0.2.1"), true)
  assert_eq(valid_ipv6("2001:db8::192.0.2.1"), true)
  assert_eq(valid_ipv6("1:2:3:4:5:6:192.0.2.1"), true)
}

///|
test "ipv6 rejects malformed embedded ipv4" {
  assert_eq(valid_ipv6("::ffff:999.0.2.1"), false)
  assert_eq(valid_ipv6("::ffff:192.0.2"), false)
  assert_eq(valid_ipv6("2001:db8:192.0.2.1"), false)
}

///|
test "ipv6 rejects too many groups" {
  assert_eq(valid_ipv6("1:2:3:4:5:6:7:8:9"), false)
  assert_eq(valid_ipv6("1:2:3:4:5:6:7:8::"), false)
}

///|
test "ipv6 rejects double compression" {
  assert_eq(valid_ipv6("1::2::3"), false)
  assert_eq(valid_ipv6(":::1"), false)
  assert_eq(valid_ipv6("1:::2"), false)
}

///|
test "ipv6 rejects oversized hexadecimal group" {
  assert_eq(valid_ipv6("12345::"), false)
  assert_eq(valid_ipv6("2001:db8:10000::1"), false)
}

///|
test "ipv6 rejects zone identifiers and bare colons" {
  assert_eq(valid_ipv6("fe80::1%eth0"), false)
  assert_eq(valid_ipv6(":"), false)
  assert_eq(valid_ipv6("1:2:3:4:5:6:7:"), false)
}

///|
test "domain validator handles wildcard and underscore labels" {
  assert_eq(valid_domain_name("*.example.org."), true)
  assert_eq(valid_domain_name("_sip._tcp.example.org."), true)
  assert_eq(valid_domain_name("example.org."), true)
}

///|
test "domain validator rejects malformed labels" {
  assert_eq(valid_domain_name("bad..example.org."), false)
  assert_eq(valid_domain_name("-bad.example.org."), false)
  assert_eq(valid_domain_name("bad-.example.org."), false)
  assert_eq(valid_domain_name("a.*.example.org."), false)
}
