# One-off edit used for assets/sprites/campesino/attack.png (see its metadata "post").
# Inputs: idle.png (blade) + the cleaned seed-5101 attack render. Args: angle, length scale, width scale.
import math, sys
from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
idle=Image.open("assets/sprites/campesino/idle.png").convert("RGBA")
atk=Image.open(f"{S}/camp_5101_clean.png").convert("RGBA")   # cleaned seed-5101 render
# 1) blade from the idle sprite (polygon around it, below the hand)
B=(109,263); T=(18,382)
m=Image.new("L",idle.size,0); ImageDraw.Draw(m).polygon([(100,258),(120,262),(116,276),(32,392),(8,388),(14,376)],fill=255)
blade=idle.copy(); a=np.array(blade); a[np.array(m)==0,3]=0; blade=Image.fromarray(a)
# 2) erase the dark stick beyond the fist
base=(254,146)
mm=Image.new("L",atk.size,0); ImageDraw.Draw(mm).line([(258,144),(330,108)],fill=255,width=16)
a=np.array(atk); a[np.array(mm)>0,3]=0; atk=Image.fromarray(a)
# 3) rotate the blade so B sits at the fist, pointing up-right toward the enemy;
#    shorter (kl) so it fits the frame, broader (kw) and brighter so it reads as steel
ang=math.radians(float(sys.argv[1]) if len(sys.argv)>1 else 38)
kl=float(sys.argv[2]) if len(sys.argv)>2 else 0.5
kw=float(sys.argv[3]) if len(sys.argv)>3 else 1.4
L=math.hypot(T[0]-B[0],T[1]-B[1])
us=((T[0]-B[0])/L,(T[1]-B[1])/L); vs=(-us[1],us[0])
uo=(math.cos(ang),-math.sin(ang)); vo=(-uo[1],uo[0])
# src = B + (d.uo/kl) us + (d.vo/kw) vs   with d = q - base
A =us[0]*uo[0]/kl+vs[0]*vo[0]/kw; Bm=us[0]*uo[1]/kl+vs[0]*vo[1]/kw
D =us[1]*uo[0]/kl+vs[1]*vo[0]/kw; E =us[1]*uo[1]/kl+vs[1]*vo[1]/kw
Cc=B[0]-(A*base[0]+Bm*base[1]); F=B[1]-(D*base[0]+E*base[1])
moved=blade.transform(atk.size,Image.AFFINE,(A,Bm,Cc,D,E,F),resample=Image.BICUBIC)
mv=np.array(moved).astype(float)
mv[:,:,:3]=np.clip(mv[:,:,:3]*1.9+np.array([8,12,22]),0,255)   # polished steel
moved=Image.fromarray(mv.astype(np.uint8))
out=atk.copy(); out.alpha_composite(moved)
# 4) put the fist back on top (the fingers wrap the handle)
fist=Image.open(f"{S}/camp_5101_clean.png").convert("RGBA").crop((228,128,262,166))
fm=np.array(fist); keep=(fm[:,:,0].astype(int)-fm[:,:,2].astype(int))>18   # skin is warmer than the dark stick
fm[~keep,3]=0; out.alpha_composite(Image.fromarray(fm),(228,128))
out.save(f"{S}/camp_attack_machete.png")
bg=Image.new("RGBA",out.size,(58,42,30,255)); bg.alpha_composite(out); bg.convert("RGB").resize((640,960)).save(f"{S}/camp_attack_machete_view.png")
