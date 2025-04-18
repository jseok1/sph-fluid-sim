from math import ceil

import pandas as pd

WORKGROUP_SIZE = 256
RADIX = 256

front = pd.read_csv("f.csv")[" g_handles_front.hash"]
n = len(front.index)

n_workgroups_1 = n // WORKGROUP_SIZE
n_workgroups_2 = ceil(n_workgroups_1 / WORKGROUP_SIZE)
n_workgroups_3 = ceil(n_workgroups_2 / WORKGROUP_SIZE)

print(n)

histogram = [0] * RADIX * (n_workgroups_1 + n_workgroups_2 + n_workgroups_3)

for wid in range(n_workgroups_1):
    for l_tid in range(WORKGROUP_SIZE):
        g_tid = WORKGROUP_SIZE * wid + l_tid
        digit = front[g_tid] & 0xFF

        histogram[digit * n_workgroups_1 + wid] += 1

for wid in range(n_workgroups_1):
    total = 0
    for l_tid in range(WORKGROUP_SIZE):
        g_tid = WORKGROUP_SIZE * wid + l_tid
        histogram[g_tid], total = total, total + histogram[g_tid]
        if l_tid == WORKGROUP_SIZE - 1:
            histogram[RADIX * n_workgroups_1 + wid] = histogram[g_tid]

for wid in range(n_workgroups_2):
    total = 0
    for l_tid in range(WORKGROUP_SIZE):
        g_tid = WORKGROUP_SIZE * (n_workgroups_1 + wid) + l_tid
        histogram[g_tid], total = total, total + histogram[g_tid]
        if l_tid == WORKGROUP_SIZE - 1:
            histogram[RADIX * (n_workgroups_1 + n_workgroups_2) + wid] = histogram[
                g_tid
            ]

total = 0
for l_tid in range(WORKGROUP_SIZE):
    g_tid = WORKGROUP_SIZE * (n_workgroups_1 + n_workgroups_2) + l_tid
    histogram[g_tid], total = total, total + histogram[g_tid]

offsets = list(pd.read_csv("offsets.csv")[" g_histogram"])
print(histogram == offsets)

# compute scatter offset:

with open("out.csv", "w") as f:
    for x in histogram:
        f.write(f"{x}\n")

g_tid = 42
# g_tid = 44
l_tid = g_tid % WORKGROUP_SIZE
wid = g_tid // WORKGROUP_SIZE

digit = front[g_tid] & 0xFF

hist_idx = digit * n_workgroups_1 + wid
hist_idx_2 = RADIX * n_workgroups_1 + hist_idx // WORKGROUP_SIZE
hist_idx_3 = (
    RADIX * (n_workgroups_1 + n_workgroups_2)
    + (hist_idx_2 - RADIX * n_workgroups_1) // WORKGROUP_SIZE
)

g_offset = histogram[hist_idx] + histogram[hist_idx_2] + histogram[hist_idx_3]

l_histogram = [0] * RADIX
for _l_tid in range(WORKGROUP_SIZE):
    _g_tid = WORKGROUP_SIZE * wid + _l_tid
    if _l_tid == 0 or (front[_g_tid - 1] & 0xFF) != (front[_g_tid] & 0xFF):
        l_histogram[front[_g_tid] & 0xFF] = _l_tid


l_offset = l_histogram[digit]

print("hist_idx", hist_idx)
print("RADIX * WORKGROUPS + hist_idx // WORKGROUP_SIZE", hist_idx_2)

print("g_tid", g_tid)
print("digit", digit)
print("l_tid", l_tid)
print("g_offset", g_offset, f"({histogram[hist_idx]} + {histogram[hist_idx_2]} + {histogram[hist_idx_3]})")
print("l_offset", l_offset)
print("l_tid - l_offset + g_offset", l_tid - l_offset + g_offset)


# Element, log.g_tid, log.l_tid, log.g_offset, log.l_offset, log.scatter
#  32554,         42,        42, (255?)  5376,           42,        5376
#  32556,         44,        44, (255?)  5376,           44,        5376


# recap: there's a collision in Python's implementation of global offsets, therefore the algorithm
# is buggy?
# but also the GPU hist and this one don't align so there's another bug somewhere :(

# 32**3 = 32768 elements
# ceil(32768 / 256) = 128 offset elements
# ceil(128 / 256) = 1 offset element

# What I know:
# RenderDoc buffers change?
# goffset is sus