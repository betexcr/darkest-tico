# One-off edit used for assets/sprites/campesino/attack.png (see its metadata "post").
# Input: the seed-5203 attack render (--redo-tries preview) + idle.png (blade). Args: angle, length scale, width scale.
import math, sys
from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
src=Image.open(f"{S}/attack_tries/campesino/attack_5203.png").convert("RGBA")
atk=src.copy()
def erase(draw_fn):
    global atk
    m=Image.new("L",atk.size,0); draw_fn(ImageDraw.Draw(m))
    a=np.array(atk); a[np.array(m)>0,3]=0; atk=Image.fromarray(a)
# 1) the hat-shaped disc behind him
erase(lambda d: d.polygon([(22,150),(36,95),(80,68),(140,68),(166,78),(150,96),(140,112),(133,140),(131,172),(141,192),(124,214),(108,234),(58,236),(26,200)],fill=255))
# 2) the machete in the low trailing hand
erase(lambda d: d.line([(124,244),(100,280),(60,315),(20,345)],fill=255,width=26))
# 3) the stub blade on the raised fist
erase(lambda d: d.line([(268,64),(296,30)],fill=255,width=12))
# 4) steel blade from the idle sprite, on a 45-degree line from the raised RIGHT fist
idle=Image.open("assets/sprites/campesino/idle.png").convert("RGBA")
B=(109,263); T=(18,382)
m=Image.new("L",idle.size,0); ImageDraw.Draw(m).polygon([(100,258),(120,262),(116,276),(32,392),(8,388),(14,376)],fill=255)
blade=idle.copy(); a=np.array(blade); a[np.array(m)==0,3]=0; blade=Image.fromarray(a)
base=(263,70); ang=math.radians(float(sys.argv[1]) if len(sys.argv)>1 else 45)
kl=float(sys.argv[2]) if len(sys.argv)>2 else 0.52; kw=float(sys.argv[3]) if len(sys.argv)>3 else 1.2
L=math.hypot(T[0]-B[0],T[1]-B[1]); us=((T[0]-B[0])/L,(T[1]-B[1])/L); vs=(-us[1],us[0])
uo=(math.cos(ang),-math.sin(ang)); vo=(-uo[1],uo[0])
A=us[0]*uo[0]/kl+vs[0]*vo[0]/kw; Bm=us[0]*uo[1]/kl+vs[0]*vo[1]/kw
D=us[1]*uo[0]/kl+vs[1]*vo[0]/kw; E=us[1]*uo[1]/kl+vs[1]*vo[1]/kw
Cc=B[0]-(A*base[0]+Bm*base[1]); F=B[1]-(D*base[0]+E*base[1])
moved=blade.transform(atk.size,Image.AFFINE,(A,Bm,Cc,D,E,F),resample=Image.BICUBIC)
mv=np.array(moved).astype(float); mv[:,:,:3]=np.clip(mv[:,:,:3]*1.9+np.array([8,12,22]),0,255)
out=atk.copy(); out.alpha_composite(Image.fromarray(mv.astype(np.uint8)))
# 5) fingers back over the handle
fist=src.crop((246,58,276,92)); fm=np.array(fist)
keep=(fm[:,:,0].astype(int)-fm[:,:,2].astype(int))>18; fm[~keep,3]=0
out.alpha_composite(Image.fromarray(fm),(246,58))
out.save(f"{S}/camp_attack_v2.png")
bg=Image.new("RGBA",out.size,(58,42,30,255)); bg.alpha_composite(out); bg.convert("RGB").resize((640,960)).save(f"{S}/camp_attack_v2_view.png")
# 6) leftovers: the disc's dark wedge behind the back, and the old blade's silver handle in the left fist
out=Image.open(f"{S}/camp_attack_v2.png").convert("RGBA")
m=Image.new("L",out.size,0); ImageDraw.Draw(m).polygon([(128,118),(147,118),(146,150),(150,184),(141,194),(128,196)],fill=255)
ImageDraw.Draw(m).polygon([(108,218),(121,218),(119,236),(108,238)],fill=255)
a=np.array(out); a[np.array(m)>0,3]=0
box=a[224:250,110:140]; rgb=box[:,:,:3].astype(int)
bright=(rgb.mean(axis=2)>140)&((rgb.max(axis=2)-rgb.min(axis=2))<40)
box[bright,0:3]=(68,48,38)
out=Image.fromarray(a); out.save(f"{S}/camp_attack_v2.png")
bg=Image.new("RGBA",out.size,(58,42,30,255)); bg.alpha_composite(out); bg.convert("RGB").resize((640,960)).save(f"{S}/camp_attack_v2_view.png")
