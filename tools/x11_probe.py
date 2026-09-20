"""Explicit desktop integration probe. Moves pointer only over the pet; no typing."""
import ctypes as c
import json, subprocess, time, re, sys
x = c.CDLL('libX11.so.6'); xt = c.CDLL('libXtst.so.6'); ext = c.CDLL('libXext.so.6')
P=c.c_void_p; U=c.c_ulong; I=c.c_int
for name, args, result in [('XOpenDisplay',[c.c_char_p],P),('XDefaultRootWindow',[P],U),('XGetInputFocus',[P,c.POINTER(U),c.POINTER(I)],I),('XFlush',[P],I),('XTranslateCoordinates',[P,U,U,I,I,c.POINTER(I),c.POINTER(I),c.POINTER(U)],I),('XQueryPointer',[P,U,c.POINTER(U),c.POINTER(U),c.POINTER(I),c.POINTER(I),c.POINTER(I),c.POINTER(I),c.POINTER(c.c_uint)],I)]:
 f=getattr(x,name); f.argtypes=args; f.restype=result
xt.XTestFakeMotionEvent.argtypes=[P,I,I,I,U]; xt.XTestFakeButtonEvent.argtypes=[P,c.c_uint,I,U]
x.XWarpPointer.argtypes=[P,U,U,I,I,c.c_uint,c.c_uint,I,I]
class Rect(c.Structure): _fields_=[('x',c.c_short),('y',c.c_short),('w',c.c_ushort),('h',c.c_ushort)]
ext.XShapeGetRectangles.argtypes=[P,U,I,c.POINTER(I),c.POINTER(I)]; ext.XShapeGetRectangles.restype=c.POINTER(Rect)
d=x.XOpenDisplay(None); assert d, 'No X11 display'; root=x.XDefaultRootWindow(d)
tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
match=re.search(r'(0x[0-9a-f]+) "CP Pet '+re.escape(sys.argv[1] if len(sys.argv)>1 else 'M0'),tree); assert match, tree
w=int(match[1],16)
if '--alpha' in sys.argv:
 x.XGetImage.argtypes=[P,U,I,I,c.c_uint,c.c_uint,U,I]; x.XGetImage.restype=P
 x.XGetPixel.argtypes=[P,I,I]; x.XGetPixel.restype=U
 x.XDestroyImage.argtypes=[P]
 img=x.XGetImage(d,w,0,0,240,240,0xffffffff,2)
 assert img
 outside=x.XGetPixel(img,0,0); body=x.XGetPixel(img,120,170)
 x.XDestroyImage(img)
 print(json.dumps({'background_pixel':hex(outside),'body_pixel':hex(body),'background_alpha':outside>>24,'body_alpha':body>>24}))
 assert outside>>24==0 and body>>24==255
 sys.exit(0)
if '--capture' in sys.argv:
 destination='/tmp/cp-pet-preview-'+sys.argv[1]+'.png'
 subprocess.run(['import','-window',hex(w),destination],check=True)
 print(destination)
 sys.exit(0)
def pos():
 a=I(); b=I(); child=U(); x.XTranslateCoordinates(d,w,root,0,0,c.byref(a),c.byref(b),c.byref(child)); return a.value,b.value
def focus():
 a=U(); b=I(); x.XGetInputFocus(d,c.byref(a),c.byref(b)); return a.value
def move(a,b):
 x.XWarpPointer(d,0,root,0,0,0,0,a,b); x.XFlush(d); time.sleep(.2)
def child():
 r=U(); ch=U(); a=I(); b=I(); z=I(); q=I(); mask=c.c_uint(); x.XQueryPointer(d,root,c.byref(r),c.byref(ch),c.byref(a),c.byref(b),c.byref(z),c.byref(q),c.byref(mask)); return ch.value
def body_target():
 for _ in range(5):
  a,b=pos(); move(a+120,b+165)
  if child()==w: return a,b
 raise RuntimeError('Pointer did not land on pet; no click sent. Do not operate the mouse during this test.')
if '--menu' in sys.argv:
 a,b=body_target(); print('pointer child:',hex(child()),'target:',hex(w),'position:',pos())
 xt.XTestFakeButtonEvent(d,3,1,0); xt.XTestFakeButtonEvent(d,3,0,0); x.XFlush(d); time.sleep(.3)
 subprocess.run(['import','-window',hex(w),'/tmp/cp-pet-menu.png'],check=True)
 print('/tmp/cp-pet-menu.png')
 sys.exit(0)
if any(arg in sys.argv for arg in ['--exit-menu','--reset-menu','--pause-menu']):
 row=80 if '--exit-menu' in sys.argv else (50 if '--reset-menu' in sys.argv else 22)
 a,b=pos(); move(a+120,b+row)
 assert child()==w, 'Menu not under pointer; no click sent'
 xt.XTestFakeButtonEvent(d,1,1,0); x.XFlush(d); time.sleep(.1)
 xt.XTestFakeButtonEvent(d,1,0,0); x.XFlush(d); time.sleep(.5)
 if '--exit-menu' in sys.argv:
  tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
  assert '"CP Pet ' not in tree, 'Exit must close both windows'
  print('Exit menu closed both windows')
 sys.exit(0)
n=I(); order=I(); rs=ext.XShapeGetRectangles(d,w,2,c.byref(n),c.byref(order))
rects=[(rs[i].x,rs[i].y,rs[i].w,rs[i].h) for i in range(n.value)]
a,b=pos(); before=focus(); move(a+5,b+120); outside=child(); a,b=body_target(); inside=child()
xt.XTestFakeButtonEvent(d,1,1,0); x.XFlush(d); time.sleep(.15); move(a+180,b+125); xt.XTestFakeButtonEvent(d,1,0,0); x.XFlush(d); time.sleep(.25)
after=pos(); result={'window':hex(w),'input_rectangles':rects,'transparent_point_passes':outside!=w,'body_receives':inside==w,'moved':after!=(a,b),'focus_unchanged':focus()==before,'position_before':[a,b],'position_after':after}
print(json.dumps(result,indent=2)); assert all(result[k] for k in ['transparent_point_passes','body_receives','moved','focus_unchanged'])
