"""检查 APK 内各 native 库的 ELF 段对齐。

Android 15+ 在 16KB 内存页的设备上要求 .so 的 PT_LOAD 段按 16KB 对齐，
否则 dlopen 失败 -> 进程在启动瞬间崩溃（界面都出不来）。
zipalign -P 16 只校验 ZIP 层，不校验 ELF 层，所以必须单独查。
"""
import struct
import sys
import os

PT_LOAD = 1


def alignments(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'\x7fELF':
        return None
    is64 = data[4] == 2
    if is64:
        e_phoff = struct.unpack_from('<Q', data, 0x20)[0]
        e_phentsize = struct.unpack_from('<H', data, 0x36)[0]
        e_phnum = struct.unpack_from('<H', data, 0x38)[0]
        p_align_off = 0x30
    else:
        e_phoff = struct.unpack_from('<I', data, 0x1C)[0]
        e_phentsize = struct.unpack_from('<H', data, 0x2A)[0]
        e_phnum = struct.unpack_from('<H', data, 0x2C)[0]
        p_align_off = 0x1C

    out = []
    for i in range(e_phnum):
        base = e_phoff + i * e_phentsize
        p_type = struct.unpack_from('<I', data, base)[0]
        if p_type != PT_LOAD:
            continue
        if is64:
            p_align = struct.unpack_from('<Q', data, base + p_align_off)[0]
        else:
            p_align = struct.unpack_from('<I', data, base + p_align_off)[0]
        out.append(p_align)
    return out


def main():
    root = sys.argv[1]
    worst = 0
    checked = 0
    problems = []
    for abi in sorted(os.listdir(root)):
        d = os.path.join(root, abi)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith('.so'):
                continue
            path = os.path.join(d, name)
            al = alignments(path)
            checked += 1
            if not al:
                print('  %-14s %-32s 不是 ELF，跳过' % (abi, name))
                continue
            mn = min(al)
            worst = max(worst, mn) if worst == 0 else min(worst, mn)
            flag = 'OK' if mn >= 16384 else ('!! 未达 16KB' if mn < 16384 else 'OK')
            if mn < 16384:
                problems.append('%s/%s 对齐=%d' % (abi, name, mn))
            print('  %-14s %-32s p_align=%-6d %s' % (abi, name, mn, flag))
    print('')
    print('共检查 %d 个 .so' % checked)
    if problems:
        print('!! 有 %d 个库未按 16KB 对齐（16KB 页设备上会启动即崩）:' % len(problems))
        for p in problems:
            print('   - ' + p)
    else:
        print('全部 .so 均满足 16KB 对齐')


main()
