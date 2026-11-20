"""Independent float inference for the ResNet-20 testbench fixtures."""
import operator
import struct

SCALE = 1024


class WeightReader:
    def __init__(self, path):
        self.payload = path.read_bytes()
        if len(self.payload) != 543380:
            raise ValueError(f"Expected 543380 bytes in {path}")
        self.words = tuple(word[0] / SCALE for word in struct.iter_unpack("<h", self.payload))
        self.offset = 0

    def affine(self, in_channels, out_channels, size):
        length = in_channels * size * size
        stop = self.offset + length * out_channels
        kernels = [self.words[index:index + length]
                   for index in range(self.offset, stop, length)]
        self.offset = stop + out_channels
        return kernels, self.words[stop:self.offset]


def conv(tensor, weights, out_channels, size=3, stride=1, pad=1):
    channels, height, width = tensor
    kernels, biases = weights.affine(len(channels), out_channels, size)
    padded_h, padded_w = height + 2 * pad, width + 2 * pad
    padded = [0.0] * (len(channels) * padded_h * padded_w)
    for c, plane in enumerate(channels):
        for y in range(height):
            offset = (c * padded_h + y + pad) * padded_w + pad
            padded[offset:offset + width] = plane[y * width:(y + 1) * width]

    out_h = (padded_h - size) // stride + 1
    out_w = (padded_w - size) // stride + 1
    # Build channel-major kernel patches from the padded planes.
    offsets = [(c * padded_h + ky) * padded_w + kx for c in range(len(channels))
               for ky in range(size) for kx in range(size)]
    patches = []
    for y in range(out_h):
        for x in range(out_w):
            base = stride * (y * padded_w + x)
            patches.append(tuple(padded[base + offset] for offset in offsets))
    output = [[sum(map(operator.mul, kernel, patch), bias) for patch in patches]
              for kernel, bias in zip(kernels, biases)]
    return output, out_h, out_w


def relu(tensor):
    channels, height, width = tensor
    return [[max(value, 0.0) for value in plane] for plane in channels], height, width


def block(tensor, weights, out_channels, stride, name, observe):
    skip = tensor
    if stride == 2:
        skip = conv(tensor, weights, out_channels, size=1, stride=2, pad=0)
        observe(name + ".projection", skip)
    first = relu(conv(tensor, weights, out_channels, stride=stride))
    observe(name + ".conv1", first)
    main, height, width = conv(first, weights, out_channels)
    added = [[a + b for a, b in zip(channel, shortcut)]
             for channel, shortcut in zip(main, skip[0])]
    return relu((added, height, width))


def infer(feature, weights, checkpoint=None):
    def observe(name, tensor):
        if checkpoint is not None:
            planes, _, _ = tensor
            checkpoint(name, [value for pixel in zip(*planes, strict=True) for value in pixel])

    channels = [[word / SCALE for word in feature[c::3]] for c in range(3)]
    tensor = relu(conv((channels, 32, 32), weights, 16))
    observe("stem", tensor)
    for stage, out_channels in enumerate((16, 32, 64), 1):
        for index in range(3):
            stride = 2 if out_channels != 16 and index == 0 else 1
            name = f"layer{stage}.{index}"
            tensor = block(tensor, weights, out_channels, stride, name, observe)
            if (stage, index) != (3, 2):
                observe(name + ".conv2", tensor)
    pooled = [sum(plane) / len(plane) for plane in tensor[0]]
    if checkpoint is not None:
        checkpoint(name + ".conv2", pooled)
    kernels, biases = weights.affine(64, 10, 1)
    if weights.offset != len(weights.words):
        raise ValueError("Unused weight words")
    return [sum(map(operator.mul, kernel, pooled), bias)
            for kernel, bias in zip(kernels, biases)]


def fixture_input():
    return [((i * 73 + (i // 32) * 19) % 2049) - 1024 for i in range(32 * 32 * 3)]


def write_fixture(output, weight_path):
    feature = fixture_input()
    logits = infer(feature, WeightReader(weight_path))
    output.mkdir(parents=True, exist_ok=True)
    (output / "input_q5_10.hex").write_text(
        "".join(f"{word & 0xffff:04x}\n" for word in feature),
        encoding="ascii", newline="\n")
    (output / "reference_logits_float.txt").write_text(
        "".join(f"{value:.17g}\n" for value in logits), encoding="ascii", newline="\n")
    return logits
