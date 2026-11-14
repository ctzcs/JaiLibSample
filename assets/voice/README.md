# Opus runtime (Windows x64)

`opus.dll` is libopus 1.4-14-ge6fd7f5-dirty, copied byte-for-byte from the installed Odin SDL3 mixer vendor runtime (`vendor/sdl3/mixer/libopus-0.dll`). Only the filename changes for the JaiLib voice loader.

SHA-256: `064aaa2aee76ac93df0f9ec78a670a49954e3f4ac1bc1fd70ebda2f035ccc073`

The accompanying BSD license permits binary redistribution. The DLL imports only Windows `KERNEL32.dll` and `msvcrt.dll`. `tools/stage_runtime.py` stages this DLL and its license beside sample executables. RNNoise remains optional.
