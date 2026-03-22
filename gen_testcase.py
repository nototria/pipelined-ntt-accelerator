import sys
import os
import random

def main():
    if len(sys.argv) <3:
        exit(1)
    n = 2**int(sys.argv[1])
    test_cnt = int(sys.argv[2])
    
    try:
        os.mkdir("testcase")
    except FileExistsError:
        ...
    for i in range(1, test_cnt+1):
        file = open('testcase/'+str(i)+'.txt', mode='w')
        hex_file = open('testcase/'+str(i)+'.hex', mode='w')
        
        for _ in range(n):
            a_list = [random.randrange(998244353) for _ in range(n)]
            file.writelines(map(lambda num:f"{num:d} ", a_list))
            file.write('\n')
            hex_file.writelines(map(lambda num:f"{num:08x}", reversed(a_list)))
            hex_file.write('\n')

        file.close()
        hex_file.close()

if __name__=='__main__':
    main()
