import pandas as pd

from collections import Counter

log = pd.read_csv('log.csv')
print(len(set(log[' log'])))  # missing !!!

front = pd.read_csv('front.csv')
print(len(set(front[' g_handles_front.index']))) 

back = pd.read_csv('back.csv')
print(len(set(back[' g_handles_back.index']))) 

# sim = pd.read_csv('log8168-before.csv')
# front = pd.read_csv('front8168-before.csv')
# back = pd.read_csv('back8168-before.csv')

# sim = pd.read_csv('log8168-after.csv')
# front = pd.read_csv('front8168-after.csv')
# back = pd.read_csv('back8168-after.csv')

sim = pd.read_csv('log8168-before.csv')
front = pd.read_csv('fr.csv')
back = pd.read_csv('bk.csv')

# 512 is ok, 1024 is not

x = Counter(sim[' log'])
y = Counter(front[' g_handles_front.hash'])
z = Counter(back[' g_handles_back.hash'])

print('front', x - y)
print('front', x == y)
print()
print('back', x - z)
print('back', x == z)
# before scatter, front is all 0
# after scatter, front == back (because I copy back to front)
# but also before scatter, back is correct
# the scatter operation MODIFIES THE BACK BUFFER

print([k for k,v in Counter(front[' g_handles_front.index']).items() if v > 1 ])