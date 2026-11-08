import sys
from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
dx,dy,rot=int(sys.argv[1]),int(sys.argv[2]),float(sys.argv[3])
atk=Image.open(f"{S}/camp_left.png").convert("RGBA")       # the installed attack before this fix
idle=Image.open("assets/sprites/campesino/idle.png").convert("RGBA")
a=np.array(atk); H,W=a.shape[:2]; ys,xs=np.mgrid[0:H,0:W]
# remove the chopped fist and the stub left by the machete erase
m=Image.new("L",atk.size,0); ImageDraw.Draw(m).polygon([(187,236),(214,236),(214,266),(187,266)],fill=255)
a[np.array(m)>0,3]=0
out=Image.fromarray(a)
hand=idle.crop((198,229,222,267)).rotate(rot,expand=True,resample=Image.BICUBIC)
out.alpha_composite(hand,(dx,dy))
out.save(f"{S}/camp_left_hand.png")
bg=Image.new("RGBA",out.size,(58,42,30,255)); bg.alpha_composite(out)
bg.convert("RGB").crop((130,160,260,300)).resize((390,420),Image.LANCZOS).save(f"{S}/camp_hand_zoom.png")
