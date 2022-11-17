
def get_tuser(counting):
    def nibblesum(num):
        y = num
        s = 0
        while y:
            s += (y & 0xF)
            y = y >> 4

        return s

    ret = [0 for i in counting]
    for id, x in enumerate(counting):
        ret[id] =  0x1 if ((x & 0xF) == 0xF) else 0
        ret[id] += 0x2 if ((nibblesum(x) & 0x1F) == 0x5) else 0
        ret[id] += 0x4 if (((x*3) >> 3) == 0x7) else 0
        ret[id] += 0x8 if ((x & 0x7F) == 0xA) else 0
        ret[id] += 0x10 if (ret[id] == 0xF) else 0

    return ret


        
        
        
                
            
            
            



