///|
/// RFC 1982 serial-number arithmetic yields an undefined region at exactly half the space.
pub(all) enum SerialOrder {
  Same
  Forward
  Backward
  Undefined
} derive(Eq, Debug)

///|
pub fn parse_serial(input : String) -> UInt? {
  let chars = input.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut number = 0U
  for c in chars {
    if !is_digit(c) {
      return None
    }
    let digit = (c.to_int() - '0'.to_int()).reinterpret_as_uint()
    if number > (4294967295U - digit) / 10U {
      return None
    }
    number = number * 10U + digit
  }
  Some(number)
}

///|
pub fn compare_serial(before : UInt, after : UInt) -> SerialOrder {
  let delta = after - before
  if delta == 0U {
    Same
  } else if delta == 2147483648U {
    Undefined
  } else if delta < 2147483648U {
    Forward
  } else {
    Backward
  }
}

///|
fn apex_serial(zone : Zone) -> UInt? {
  for record in zone.records {
    if record.owner == zone.origin &&
      record.record_type == "SOA" &&
      record.rdata.length() == 7 {
      return parse_serial(record.rdata[2])
    }
  }
  None
}
