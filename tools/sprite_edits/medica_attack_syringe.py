from PIL import Image, ImageDraw
import numpy as np
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
base=Image.open(f"{S}/attack_tries/medica_josefina/attack_5361.png").convert("RGBA")
old=Image.open(f"{S}/medica_attack_5121.png").convert("RGBA")
# fist + syringe from the earlier attack (pointing right, ~12 deg up)
fist=old.crop((226,130,292,174))
fa=np.array(fist)
fa[:,:4,3]=0
fist=Image.fromarray(fa)
fist=fist.rotate(33,expand=True,resample=Image.BICUBIC)        # now ~45 deg up toward the enemy
# remove the open hand
a=np.array(base); m=Image.new("L",base.size,0)
ImageDraw.Draw(m).polygon([(244,62),(252,46),(270,44),(276,56),(268,74),(252,82)],fill=255)
a[np.array(m)>0,3]=0
out=Image.fromarray(a)
fw,fh=fist.size
# fist centre (in the rotated crop) on the wrist end of the raised sleeve
out.alpha_composite(fist,(250-fw//2+6,64-fh//2))
out.save(f"{S}/med_hand.png")
