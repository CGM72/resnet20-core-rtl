"""Independent arbitrary-precision Q5.10 layer oracle (no RTL simulation)."""
from pathlib import Path
import operator
import struct


def sat(value):
    return max(-32768, min(32767, value))


def rounded(value, denominator):
    magnitude = (abs(value) + denominator // 2) // denominator
    return -magnitude if value < 0 else magnitude


def write_quantized_layers(output, weight_path, program, feature):
    weights = [item[0] for item in struct.iter_unpack('<h', Path(weight_path).read_bytes())]
    shortcut = []
    offset = 0
    folder = Path(output) / 'expected'
    folder.mkdir(parents=True, exist_ok=True)
    checked = 0
    for index, (name, op, width, height, cin, cout, size, stride, pad) in enumerate(program):
        if op == 1:
            continue
        if op == 128:
            shortcut = feature[:]
            continue
        taps = cin * size * size
        kernels = [weights[offset + oc*taps:offset + (oc+1)*taps] for oc in range(cout)]
        bias_base = offset + taps*cout
        biases = weights[bias_base:bias_base+cout]
        offset = bias_base + cout
        out_h = (height + 2*pad - size)//stride + 1
        out_w = (width + 2*pad - size)//stride + 1
        # HWC patches, ordered independently from the TB's per-tap address scheduler.
        patches = []
        for y in range(out_h):
            for x in range(out_w):
                patch = []
                for ic in range(cin):
                    for ky in range(size):
                        for kx in range(size):
                            iy, ix = y*stride + ky-pad, x*stride+kx-pad
                            patch.append(feature[(iy*width+ix)*cin+ic]
                                         if 0 <= iy < height and 0 <= ix < width else 0)
                patches.append(patch)
        result = [0]*(out_h*out_w*cout)
        for oc, (kernel, bias) in enumerate(zip(kernels, biases)):
            for pixel, patch in enumerate(patches):
                value = sat(rounded(sum(map(operator.mul, kernel, patch)) + bias*1024, 1024))
                if op & 32:
                    value = sat(value + shortcut[pixel*cout+oc])
                if op & 16:
                    value = max(0, value)
                result[pixel*cout+oc] = value
        if op & 4:
            result = [rounded(sum(result[oc::cout]), out_h*out_w) for oc in range(cout)]
        (folder/f'layer_{index:02d}.hex').write_text(
            ''.join(f'{v & 0xffff:04x}\n' for v in result), encoding='ascii')
        if op == 192:
            shortcut = result
        else:
            feature = result
        checked += 1
    if offset != len(weights):
        raise ValueError(f'Consumed {offset} weight words, expected {len(weights)}')
    print(f'Integer oracle: {checked} affine layers, {offset*2} weight bytes; logits={feature}')
    return feature
