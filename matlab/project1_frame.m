function bytes = project1_frame(kind, seq, payload)
%PROJECT1_FRAME Build A5 5A | TYPE | SEQ | LEN | PAYLOAD | CRC_LO | CRC_HI.
arguments
    kind (1,1) uint8
    seq (1,1) uint8 = uint8(0)
    payload (1,:) uint8 = uint8([])
end
if numel(payload)>64, error('Payload length exceeds protocol limit'); end
body = uint8([kind,seq,uint8(numel(payload)),payload]);
crc = project1_crc16(body);
bytes = [uint8([165,90]),body,uint8(bitand(crc,uint16(255))),uint8(bitshift(crc,-8))];
end
