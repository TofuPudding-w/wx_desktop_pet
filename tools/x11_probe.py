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
menu_action = any(arg.endswith('-menu') for arg in sys.argv) and not any(arg in sys.argv for arg in ['--restore-menu', '--exit-hidden-menu'])
if menu_action:
 match=re.search(r'(0x[0-9a-f]+) \"CP Pet Menu',tree)
 assert match, 'No menu window is open; no click sent'
w=int(match[1],16)
geometry=subprocess.check_output(['xwininfo','-id',hex(w)],text=True)
width=int(re.search(r'Width: (\d+)',geometry)[1]); height=int(re.search(r'Height: (\d+)',geometry)[1])
hidden = sys.argv[1] == "Hidden"
factor=width/(276 if menu_action else (232 if hidden else 320))
body_x, body_y = (192,112) if hidden else (160,240)
if not hidden and "--menu" in sys.argv:
 body_y = 320  # The taller menu covers y=240; reopen via the visible lower body.
def px(value): return round(value*factor)
if '--alpha' in sys.argv:
 x.XGetImage.argtypes=[P,U,I,I,c.c_uint,c.c_uint,U,I]; x.XGetImage.restype=P
 x.XGetPixel.argtypes=[P,I,I]; x.XGetPixel.restype=U
 x.XDestroyImage.argtypes=[P]
 img=x.XGetImage(d,w,0,0,width,height,0xffffffff,2)
 assert img
 outside=x.XGetPixel(img,0,0); body=x.XGetPixel(img,px(body_x),px(body_y))
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
 xt.XTestFakeMotionEvent(d,-1,a,b,0); x.XFlush(d); time.sleep(.2)
def child():
 r=U(); ch=U(); a=I(); b=I(); z=I(); q=I(); mask=c.c_uint(); x.XQueryPointer(d,root,c.byref(r),c.byref(ch),c.byref(a),c.byref(b),c.byref(z),c.byref(q),c.byref(mask)); return ch.value
def body_target():
 for _ in range(5):
  a,b=pos(); move(a+px(body_x),b+px(body_y))
  if child()==w: return a,b
 raise RuntimeError('Pointer did not land on pet; no click sent. Do not operate the mouse during this test.')
if '--menu' in sys.argv:
 a,b=body_target(); print('pointer child:',hex(child()),'target:',hex(w),'position:',pos())
 xt.XTestFakeButtonEvent(d,3,1,0); xt.XTestFakeButtonEvent(d,3,0,0); x.XFlush(d); time.sleep(.3)
 tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
 menu_match=re.search(r'(0x[0-9a-f]+) \"CP Pet Menu',tree)
 assert menu_match, 'Menu did not open'
 subprocess.run(['import','-window',menu_match[1],'/tmp/cp-pet-menu.png'],check=True)
 print('/tmp/cp-pet-menu.png')
 sys.exit(0)
if any(arg in sys.argv for arg in ['--exit-menu','--reset-menu','--pause-menu','--settings-menu','--size150-menu','--size200-menu','--size100-menu','--size-menu','--hide-menu','--restore-menu','--exit-hidden-menu','--help-menu','--guide-menu','--updates-menu','--check-update-menu']):
 rows={'--exit-menu':190,'--reset-menu':78,'--pause-menu':22,'--settings-menu':106,'--size-menu':22,'--hide-menu':78,'--restore-menu':22,'--exit-hidden-menu':50,'--help-menu':162,'--updates-menu':106,'--check-update-menu':106,'--guide-menu':22,'--size150-menu':78,'--size200-menu':134,'--size100-menu':22}
 row=next(value for flag,value in rows.items() if flag in sys.argv)
 if not hidden:
  if '--check-update-menu' in sys.argv:
   row=168
  else:
   row=80 + round((row-22)/28)*34
 for _ in range(5):
  a,b=pos(); move(a+px(138 if menu_action else (112 if hidden else 160)),b+px(row-8 if menu_action else row))
  if child()==w: break
 assert child()==w, 'Menu not under pointer; no click sent'
 xt.XTestFakeButtonEvent(d,1,1,0); x.XFlush(d); time.sleep(.1)
 xt.XTestFakeButtonEvent(d,1,0,0); x.XFlush(d); time.sleep(.5)
 if '--exit-menu' in sys.argv or '--exit-hidden-menu' in sys.argv:
  for _ in range(30):
   tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
   if '"CP Pet ' not in tree: break
   time.sleep(.1)
  assert '"CP Pet ' not in tree, 'Exit must close both windows'
  print('Exit menu closed both windows')
 sys.exit(0)
if '--icon-input' in sys.argv:
 a,b=pos(); before=focus(); move(a+px(5),b+px(120)); assert child()!=w, 'Transparent icon surroundings block clicks'
 body_target(); assert focus()==before, 'Icon stole focus'
 print('PASS: restore icon hit region, click-through and focus')
 sys.exit(0)
n=I(); order=I(); rs=ext.XShapeGetRectangles(d,w,2,c.byref(n),c.byref(order))
rects=[(rs[i].x,rs[i].y,rs[i].w,rs[i].h) for i in range(n.value)]
a,b=pos(); before=focus(); move(a+px(5),b+px(120)); outside=child(); a,b=body_target(); inside=child()
xt.XTestFakeButtonEvent(d,1,1,0); x.XFlush(d); time.sleep(.15); move(a+px(body_x-180 if hidden else 200),b+px(body_y-90 if hidden else 170)); xt.XTestFakeButtonEvent(d,1,0,0); x.XFlush(d); time.sleep(.25)
after=pos(); result={'window':hex(w),'input_rectangle_count':len(rects),'transparent_point_passes':outside!=w,'body_receives':inside==w,'moved':after!=(a,b),'focus_unchanged':focus()==before,'position_before':[a,b],'position_after':after}
print(json.dumps(result,indent=2)); assert all(result[k] for k in ['transparent_point_passes','body_receives','moved','focus_unchanged'])
