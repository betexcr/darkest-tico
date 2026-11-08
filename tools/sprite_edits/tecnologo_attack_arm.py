# One-off edit for assets/sprites/tecnologo/attack.png (see its metadata "post"): near (right) arm raised.
import math
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
im=Image.open("/home/user/darkest-tico/assets/sprites/tecnologo/attack.png").convert("RGBA")
a=np.array(im)
# 1) erase the near hand hanging out past the coat at the hip
# only the glove that sticks out to the right of the coat edge (coat edge ~ x=203 there)
m=Image.new("L",im.size,0); ImageDraw.Draw(m).polygon([(206,226),(230,226),(230,272),(198,272),(203,250)],fill=255)
a[np.array(m)>0,3]=0
base=Image.fromarray(a)
# 2) leather texture: a straight strip cut along the existing sleeve (hand side toward the root)
src=Image.open("/home/user/darkest-tico/assets/sprites/tecnologo/attack.png").convert("RGBA")
p0=(244,88); p1=(214,108)                      # along the sleeve: hand -> root
L=math.hypot(p1[0]-p0[0],p1[1]-p0[1]); ang=math.degrees(math.atan2(p1[1]-p0[1],p1[0]-p0[0]))
rot=src.rotate(ang,center=p0,resample=Image.BICUBIC)       # sleeve now horizontal to the right of p0
strip=rot.crop((p0[0],p0[1]-11,p0[0]+int(L),p0[1]+11))
# 3) new upper arm from the near shoulder (front of chest) up to the sleeve root
q0=(190,152); q1=(220,110)
Lq=math.hypot(q1[0]-q0[0],q1[1]-q0[1])
st=strip.resize((int(Lq)+6,22),Image.BICUBIC)
angq=math.degrees(math.atan2(q1[1]-q0[1],q1[0]-q0[0]))
canvas=Image.new("RGBA",im.size,(0,0,0,0)); canvas.paste(st,(q0[0],q0[1]-11))
canvas=canvas.rotate(-angq,center=q0,resample=Image.BICUBIC)
# soften the strip's ends
al=np.array(canvas)[:,:,3].astype(float)
mask=Image.new("L",im.size,0); ImageDraw.Draw(mask).line([q0,q1],fill=255,width=22)
mask=mask.filter(ImageFilter.GaussianBlur(2))
ca=np.array(canvas); ca[:,:,3]=np.minimum(al,np.array(mask)).astype(np.uint8)
out=base.copy(); out.alpha_composite(Image.fromarray(ca))
out.save(f"{S}/tec_edit1.png")
