import pandas as pd

WORKGROUP_SIZE = 256
RADIX = 256

front = pd.read_csv("f.csv")[" g_handles_front.hash"]
n = len(front.index)

n_workgroups = n // WORKGROUP_SIZE

histogram = [0] * RADIX * (n_workgroups + 1)

for wid in range(n_workgroups):
    for l_tid in range(WORKGROUP_SIZE):
        g_tid = WORKGROUP_SIZE * wid + l_tid
        digit = front[g_tid] & 0xFF

        histogram[digit * n_workgroups + wid] += 1

for wid in range(n_workgroups):
    total = 0
    for l_tid in range(WORKGROUP_SIZE):
        g_tid = WORKGROUP_SIZE * wid + l_tid
        histogram[g_tid], total = total, total + histogram[g_tid]
        if l_tid == WORKGROUP_SIZE - 1:
            histogram[RADIX * n_workgroups + wid] = histogram[g_tid]

total = 0
for l_tid in range(WORKGROUP_SIZE):
    g_tid = WORKGROUP_SIZE * 4 + l_tid
    histogram[g_tid], total = total, total + histogram[g_tid]

offsets = list(pd.read_csv("offsets.csv")[" g_offsets"])
print(histogram == offsets)

# compute scatter offset:

with open('out.csv', 'w') as f:
    for x in histogram:
        f.write(f"{x}\n")

# g_tid = 451
g_tid = 482
l_tid = g_tid % WORKGROUP_SIZE
wid = g_tid // WORKGROUP_SIZE

digit = front[g_tid] & 0xFF

hist_idx = digit * n_workgroups + wid
g_offset = histogram[hist_idx] + histogram[RADIX * n_workgroups + hist_idx // WORKGROUP_SIZE]

l_offsets = [0] * RADIX
for _l_tid in range(WORKGROUP_SIZE):
    _g_tid = WORKGROUP_SIZE * wid + _l_tid
    if _l_tid == 0 or (front[_g_tid - 1] & 0xFF) != (front[_g_tid] & 0xFF):
        l_offsets[front[_g_tid] & 0xFF] = _l_tid


l_offset = l_offsets[digit]


print("g_tid", g_tid)
print("digit", digit)
print("l_tid", l_tid)
print("g_offset", g_offset, f'{histogram[digit * n_workgroups + wid]} + {histogram[RADIX * n_workgroups + hist_idx // WORKGROUP_SIZE]}')
print("l_offset", l_offset)
print("l_tid - l_offset + g_offset", l_tid - l_offset + g_offset)
