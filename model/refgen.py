import sys
from tuser import *

COUNT_START = int(sys.argv[1])
f = open(sys.argv[2], "w")

ref = range(COUNT_START,-1,-1)
tuser = get_tuser(ref)


for id,i in enumerate(ref):
    f.write("{0:05b}".format(tuser[id]) + "{0:032b}".format(i)  + "\n")

f.close()






