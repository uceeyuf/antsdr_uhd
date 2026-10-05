// SPDX-License-Identifier: AGPL-3.0-or-later
// Decode a CRC-validated BCCH-DL-SCH transport block using srsRAN ASN.1.
#include "srsran/asn1/rrc.h"
#include <iostream>
#include <string>
#include <vector>
static int nibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}
int main(int argc, char** argv) {
  if (argc != 2) { std::cerr << "Usage: decode_sib1 HEX_TRANSPORT_BLOCK\n"; return 2; }
  const std::string hex = argv[1];
  if (hex.empty() || hex.size() % 2 || hex.size() > 32000) return 2;
  std::vector<uint8_t> bytes;
  for (size_t i = 0; i < hex.size(); i += 2) {
    int hi = nibble(hex[i]), lo = nibble(hex[i+1]);
    if (hi < 0 || lo < 0) return 2;
    bytes.push_back(uint8_t((hi << 4) | lo));
  }
  asn1::cbit_ref bits(bytes.data(), bytes.size());
  asn1::rrc::bcch_dl_sch_msg_s message;
  if (message.unpack(bits) != asn1::SRSASN_SUCCESS ||
      message.msg.type() != asn1::rrc::bcch_dl_sch_msg_type_c::types::c1 ||
      message.msg.c1().type() != asn1::rrc::bcch_dl_sch_msg_type_c::c1_c_::types::sib_type1) {
    std::cerr << "Not a valid SIB1 BCCH-DL-SCH message\n"; return 1;
  }
  asn1::json_writer json;
  message.to_json(json);
  std::cout << json.to_string() << '\n';
}
