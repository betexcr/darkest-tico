# Replace the campesino attack's chopped low (left) fist with the relaxed hand from idle.png,
# pivoted on the wrist so it continues the slant of the forearm.
# usage: camp_hand.py <wrist_x> <wrist_y> <angle_deg>
import sys
from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
wx,wy,ang=float(sys.argv[1]),float(sys.argv[2]),float(sys.argv[3])
atk=Image.open(f"{S}/camp_left.png").convert("RGBA")
idle=Image.open("assets/sprites/campesino/idle.png").convert("RGBA")
a=np.array(atk)
m=Image.new("L",atk.size,0); ImageDraw.Draw(m).polygon([(191,241),(216,236),(216,268),(193,268)],fill=255)
a[np.array(m)>0,3]=0
# old knuckles poking out left of the wrist
m2=Image.new("L",atk.size,0); ImageDraw.Draw(m2).polygon([(185,232),(196,232),(195,257),(186,257)],fill=255)
a[np.array(m2)>0,3]=0
out=Image.fromarray(a)
hand=idle.crop((198,227,222,267))           # wrist at the top (crop x ~12), fingers at the bottom
hand=hand.resize((20,36),Image.LANCZOS)      # a bit slimmer: match the forearm
layer=Image.new("RGBA",atk.size,(0,0,0,0))
layer.paste(hand,(int(wx-10),int(wy)))
layer=layer.rotate(ang,center=(wx,wy),resample=Image.BICUBIC)   # + = counter-clockwise: fingers swing forward
out.alpha_composite(layer)
out.save(f"{S}/camp_left_hand.png")
bg=Image.new("RGBA",out.size,(58,42,30,255)); bg.alpha_composite(out)
bg.convert("RGB").crop((130,160,260,300)).resize((390,420),Image.LANCZOS).save(f"{S}/camp_hand_zoom.png")
