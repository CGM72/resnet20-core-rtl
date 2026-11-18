"""Cycle vectors for all real compute modules; arbitrary-precision integer oracle."""
from pathlib import Path
import argparse
import random
from collections import deque


def generate(output, width=16, frac=10, long_test=True):
    rng = random.Random(20261118 + width + frac)
    lo, hi = -(1 << (width-1)), (1 << (width-1))-1
    scale = 1 << frac
    def sat(v): return max(lo, min(hi, v))
    def rounded(v, n): return (-1 if v < 0 else 1)*((abs(v)+n//2)//n)
    # Event-to-output register delays: MAC 5 stages, GAP 4, other units 2.
    delays = (4,4,1,1,1,3)
    pending = [deque([None]*delay) for delay in delays]
    terms = []
    counts = [0]*6
    cycles = 0
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('w') as stream:
        def tick(reset=1, enable=1, valid=0, n=1, data=0, kernel=0, bias=0, skip=0):
            nonlocal pending, terms, cycles
            # Queue mathematical events to the public, fixed output clock for each module.
            if not reset:
                pending = [deque([None]*delay) for delay in delays]
            expected = [queue.popleft() for queue in pending]
            event = [None]*6
            if not reset:
                terms = []
            elif valid:
                event[2] = sat(data+skip) if enable else data
                event[3] = max(data, 0) if enable else data
                if not enable:
                    terms = []
                    for idx in (0,1,4,5): event[idx] = data
                elif n == 0:
                    terms = []
                else:
                    terms.append((data, kernel, bias))
                    if len(terms) == n:
                        dot = sum(d*k for d,k,_ in terms)
                        event[0] = sat(rounded(dot, scale))
                        event[1] = sat(rounded(dot+terms[0][2]*scale, scale))
                        event[4] = max(d for d,_,_ in terms)
                        if n <= 1024 and (n & (n-1)) == 0:
                            event[5] = rounded(sum(d for d,_,_ in terms), n)
                        terms = []
            for queue,value in zip(pending,event): queue.append(value)
            row = [reset,enable,valid,n,data,kernel,bias,skip]
            for i, value in enumerate(expected):
                row.extend((int(value is not None), value if value is not None else 0))
                counts[i] += int(value is not None)
            stream.write(' '.join(map(str,row))+'\n')
            cycles += 1
        def drain():
            for _ in range(max(delays)+2): tick(valid=0)
        tick(reset=0)
        tick(reset=0)
        # Bypass and signed overflow boundaries.
        for d in (lo,lo+1,-1,0,1,hi-1,hi):tick(enable=0,valid=1,data=d)
        drain()
        for d,k,b in [(1,scale//2,0),(-1,scale//2,0),(hi,hi,0),(lo,hi,0),(0,0,hi),(0,0,lo)]:
            tick(valid=1,data=d,kernel=k,bias=b,skip=d)
        drain()
        # Bias is sampled once, and signed ties include a change of sign after bias.
        for d,k,b in [(1,scale//2,1),(-2,scale//2,123),(-1,scale//2,-1),(2,scale//2,123)]:
            tick(valid=1,n=2,data=d,kernel=k,bias=b,skip=hi)
        drain()
        sizes=[1,2,4,8,16,32,64,128,256,512,1024,3,9,31,576,1023,2048]
        if long_test: sizes.append(65535)
        for n in sizes:
            for group in range(2):
                for index in range(n):
                    d = lo if group else hi
                    k = hi if index%2 else lo
                    tick(valid=1,n=n,data=d,kernel=k,bias=hi if index else lo,skip=lo)
                    if index%97==11:tick(valid=0,n=n,data=hi,kernel=hi)
            drain()
        for _ in range(80):
            n=rng.randint(1,19)
            for _ in range(3*n):
                if rng.random()<.25:tick(valid=0,n=n,data=hi,kernel=lo)
                tick(valid=1,n=n,data=rng.randint(lo,hi),kernel=rng.randint(lo,hi),
                     bias=rng.randint(lo,hi),skip=rng.randint(lo,hi))
            drain()
        # Reset incomplete groups and pending outputs; recovery must not leak old data.
        for n in (1,2,3,9):
            tick(valid=1,n=n,data=hi,kernel=hi)
            tick(reset=0)
            tick(valid=1,n=1,data=-3,kernel=scale,bias=1,skip=2)
            drain()
        # Abort any in-flight MAC/GAP stage, then verify fresh values after reset.
        for offset in range(5):
            tick(valid=1,n=1,data=hi,kernel=hi,bias=hi)
            for _ in range(offset): tick(valid=0)
            tick(reset=0)
            tick(valid=1,n=1,data=-1,kernel=scale//2)
            drain()
        # Zero repetition suppresses group modules; Add/ReLU are still single-value operators.
        for _ in range(4):tick(valid=1,n=0,data=7,kernel=scale)
        tick(valid=1,n=1,data=-7,kernel=scale)
        drain()
    print(f'Unit vectors: {cycles} cycles; outputs mac/biased_mac/add/relu/max/avg={counts}')

if __name__ == '__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--width', type=int, default=16)
    ap.add_argument('--frac', type=int, default=10)
    ap.add_argument('--quick', action='store_true')
    a=ap.parse_args()
    if not (2 <= a.width <= 32 and 0 <= a.frac < a.width):ap.error('Require 2<=width<=32, 0<=frac<width')
    generate(a.out,a.width,a.frac,not a.quick)
