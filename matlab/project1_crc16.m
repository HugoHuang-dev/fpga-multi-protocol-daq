function crc = project1_crc16(body)
%PROJECT1_CRC16 CRC-16/MODBUS over TYPE, SEQ, LEN, and PAYLOAD.
crc = uint16(65535);
for byte = reshape(uint8(body),1,[])
    crc = bitxor(crc,uint16(byte));
    for j=1:8
        if bitand(crc,uint16(1))
            crc = bitxor(bitshift(crc,-1),uint16(hex2dec('A001')));
        else
            crc = bitshift(crc,-1);
        end
    end
end
end
