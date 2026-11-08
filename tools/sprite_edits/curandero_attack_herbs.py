from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
base=Image.open(f"{S}/attack_tries/curandero/attack_5371.png").convert("RGBA")
old=Image.open(f"{S}/curandero_attack_5061.png").convert("RGBA")
part=old.crop((243,100,322,152)); pa=np.array(part)
# drop the sleeve (dark, lower-left corner of the crop)
yy,xx=np.mgrid[0:pa.shape[0],0:pa.shape[1]]
pa[(xx<14)&(yy>34),3]=0
part=Image.fromarray(pa).rotate(28,expand=True,resample=Image.BICUBIC)
a=np.array(base); m=Image.new("L",base.size,0)
ImageDraw.Draw(m).polygon([(250,58),(258,40),(276,38),(280,52),(270,68),(258,72)],fill=255)
a[np.array(m)>0,3]=0
out=Image.fromarray(a)
pw,ph=part.size
out.alpha_composite(part,(256-pw//2+16,64-ph//2-8))
out.save(f"{S}/cur_hand.png")
