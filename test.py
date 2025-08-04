smoothingRadius = 1
HASH_TABLE_SIZE = 100000000000

def interleaveBits(bits): 
  bits &= 0x000003FF                      # keep only 10 bits (3 x 10 bits = 30 bits <= 32 bits)
  bits = (bits | (bits << 16)) & 0x030000FF     # 00000011 00000000 00000000 11111111
  bits = (bits | (bits << 8))  & 0x0300F00F     # 00000011 00000000 11110000 00001111
  bits = (bits | (bits << 4))  & 0x030C30C3     # 00000011 00001100 00110000 11000011
  bits = (bits | (bits << 2))  & 0x09249249     # 00001001 00100100 10010010 01001001
  return bits


def morton(position): 
  x = position[0]
  y = position[1]
  z = position[2]
  hash = (interleaveBits(z) << 2) | (interleaveBits(y) << 1) | interleaveBits(x)
  # hash = hash % HASH_TABLE_SIZE;
  return hash


X = '\033[96m'
Y = '\033[93m'
Z = '\033[91m'
END = '\033[0m'

position = [1019, 250, 966]

print("{}x: {:010b}{}".format(X, position[0], END))
print("{}y: {:010b}{}".format(Y, position[1], END))
print("{}z: {:010b}{}".format(Z, position[2], END))

s = list(f'{morton(position):032b}')
for i in range(30):
  s[i + 2] = [Z, Y, X][i % 3] + s[i + 2] + END
s = ''.join(s)
print(f"morton: {s}")

