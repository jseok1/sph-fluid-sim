import pandas as pd

from collections import Counter

log = pd.read_csv("log.csv")
print(
    "unique:",
    len(set(log[" log.scatter"])),
    "min:",
    min(set(log[" log.scatter"])),
    "max:",
    max(set(log[" log.scatter"])),
)
# print([(k, v) for k, v in Counter(log[" log.scatter"]).items() if v > 1])

front = pd.read_csv("f.csv")
print("front unique", len(set(front[" g_handles_front.index"])))

back = pd.read_csv("b.csv")
print("back unique", len(set(back[" g_handles_back.index"])))
# print([(k, v) for k, v in Counter(back[" g_handles_back.index"]).items() if v > 1])


front_list = list(front[" g_handles_front.hash"] & 0xFF)
back_list = list(back[" g_handles_back.hash"] & 0xFF)
print("front is sorted:", front_list == sorted(front_list))
print("back is sorted:", back_list == sorted(back_list))


yes = True
for i in range(len(front_list) // 256):
    yes = yes and (
        front_list[256 * i : 256 * (i + 1)]
        == sorted(front_list[256 * i : 256 * (i + 1)])
    )
print("local radix sort working?", yes)

# sim = pd.read_csv('log8168-before.csv')
# front = pd.read_csv('front8168-before.csv')
# back = pd.read_csv('back8168-before.csv')

# sim = pd.read_csv('log8168-after.csv')
# front = pd.read_csv('front8168-after.csv')
# back = pd.read_csv('back8168-after.csv')

# sim = pd.read_csv('log8168-before.csv')
# front = pd.read_csv('fr.csv')
# back = pd.read_csv('bk.csv')

# 512 is ok, 1024 is not

# x = Counter(sim[' log'])
# y = Counter(front[' g_handles_front.hash'])
# z = Counter(back[' g_handles_back.hash'])

# print('front', x - y)
# print('front', x == y)
# print()
# print('back', x - z)
# print('back', x == z)
# before scatter, front is all 0
# after scatter, front == back (because I copy back to front)
# but also before scatter, back is correct
# the scatter operation MODIFIES THE BACK BUFFER

print([k for k,v in Counter(log[' log.scatter']).items() if v > 1 ])

# Element, log.g_tid, log.l_tid, log.g_offset, log.l_offset, log.scatter
#      451,      451,        195,         725,          195,     725
#      482,      482,        226,         725,          226,     725

# something is wrong here ^
# scatter IDs should be unique

# 451 hash is 19328 --> 19328 & 0xFF = 128
# 482 hash is 17600 --> 17600 & 0xFF = 192
# both 451, 482 are workgroup 1

# g_offset is wrong
# is l_offset wrong?

# offsets[4 * 128 + 1 (513)] = 0 + 725
# offsets[4 * 192 + 1 (769)] = 0 + 875????

# g_offset should be 566 and 875, respectively -- why is it 725?


# scatter offsets have duplicates
# l_tid is correct


