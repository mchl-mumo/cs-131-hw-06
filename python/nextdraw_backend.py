# PROVIDED: DO NOT EDIT.
# Chooses the plotter: the mock previewer (the default), or the real NextDraw
# when the program is run with --doplot. `--out PATH` saves the preview image
# to exactly PATH (py2png and piq2png use this).

import os
import sys

_using_real = "--doplot" in sys.argv[1:]

if _using_real:
    from nextdraw import NextDraw
    print("[nextdraw_backend] Using REAL NextDraw (hardware will move!)")
else:
    from mock_nextdraw import NextDraw
    print("[nextdraw_backend] Using MOCK NextDraw (preview only)")


def using_real_plotter():
    '''True when the program was run with --doplot (the real NextDraw).'''
    return _using_real


def _out_path():
    '''The path given with --out PATH on the command line, or None.'''
    args = sys.argv[1:]
    if "--out" in args:
        i = args.index("--out")
        if i + 1 < len(args):
            return args[i + 1]
        raise SystemExit("[nextdraw_backend] --out needs a file name")
    return None


def maybe_export(nd):
    '''Save PNG/PDF preview images if --png, --pdf and/or --out PATH were
    passed on the command line (--out PATH saves to exactly PATH; the format
    comes from its extension, .png or .pdf). Call this after issuing all
    drawing commands but before nd.disconnect() (which blocks until the
    preview window is clicked). No-op in --doplot mode, since the real
    NextDraw doesn't record paths.'''
    if _using_real:
        if "--png" in sys.argv[1:] or "--pdf" in sys.argv[1:] or "--out" in sys.argv[1:]:
            print("[nextdraw_backend] --png/--pdf/--out are ignored with --doplot (nothing to export)")
        return

    out = _out_path()
    if out is not None:
        nd.export(out)

    script_stem = os.path.splitext(os.path.basename(sys.argv[0]))[0]
    if "--png" in sys.argv[1:]:
        nd.export(f"{script_stem}_preview.png")
    if "--pdf" in sys.argv[1:]:
        nd.export(f"{script_stem}_preview.pdf")
