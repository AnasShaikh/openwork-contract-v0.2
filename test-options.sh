#!/bin/bash
# Test LayerZero options with OptionsBuilder format

# Using cast to encode options properly
# Format: TYPE_3 (0x0003) + WORKER_ID (0x01) + length + optionType + gas + value

# 700K gas (0x0aae60) - KNOWN TO WORK
echo "700K gas option:"
echo "0x000301001101000000000000000000000000000aae60"

# 1M gas (0x0f4240)
echo -e "\n1M gas option:"
echo "0x00030100110100000000000000000000000000000f4240"

# Proper calculation:
# TYPE_3 = 0x0003 (2 bytes)
# WORKER_ID = 0x01 (1 byte)
# length = 0x0011 (17 bytes: 1 for optionType + 16 for gas+value)
# optionType = 0x01 (LZRECEIVE)
# gas = uint128 (16 bytes)
# value = uint128 (16 bytes, but we use 0)

# So 0x000301001101 + [16 bytes of gas as uint128]
# 700K = 0x0aae60 padded to 16 bytes = 0x000000000000000000000000000aae60
