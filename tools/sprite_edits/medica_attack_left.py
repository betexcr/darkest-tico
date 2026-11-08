from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
im=Image.open(f"{S}/attack_tries/medica_josefina/attack_5550.png").convert("RGBA")
a=np.array(im); H,W=a.shape[:2]; ys,xs=np.mgrid[0:H,0:W]
band=Image.new("L",im.size,0); ImageDraw.Draw(band).line([(170,266),(296,149)],fill=255,width=16)
b=np.array(band)>0
# 1) cut the syringe (part outside the coat/glove) as its own layer
syr=np.zeros_like(a); keep=b & (xs>=212)
syr[keep]=a[keep]
a[keep,3]=0                                  # 2) erase it from the low hand
# 3) mirror it to point up-left, scale, and put it in the raised (right) hand
s=Image.fromarray(syr).crop((205,140,305,240)).transpose(Image.FLIP_LEFT_RIGHT)
s=s.resize((int(s.width*0.62),int(s.height*0.62)),Image.LANCZOS)
out=Image.fromarray(a)
# after the flip the syringe base (near the old hand) is at the crop's bottom-right
out.alpha_composite(s,(56-s.width+6,78-s.height+8))
out.save(f"{S}/med_left.png")
bg=Image.new("RGBA",out.size,(58,42,30,255)); bg.alpha_composite(out); bg.convert("RGB").resize((640,960)).save(f"{S}/med_left_view.png")
