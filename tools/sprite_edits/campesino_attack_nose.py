# Paint a small shaded profile nose (facing left), drawn at 8x and downsampled.
from PIL import Image, ImageDraw, ImageFilter
S="/tmp/claude-0/-home-user-darkest-tico/0e0649c4-68de-512a-876e-2d9bfe94fd76/scratchpad"
import sys
src,out=sys.argv[1],sys.argv[2]
ox,oy=int(sys.argv[3]),int(sys.argv[4])      # top of the bridge (between the brows), sprite px
K=8
im=Image.open(src).convert("RGBA")
W,H=16,16
big=Image.new("RGBA",(W*K,H*K),(0,0,0,0)); d=ImageDraw.Draw(big)
P=lambda x,y:(x*K,y*K)
# nose body: bridge from (9,0) down-left to the tip (2,9), round tip, underside back to (8,11), up the cheek line (10,6)
body=[P(9,0),P(7,3),P(4,6.5),P(2,9),P(2.2,10.6),P(4,11.4),P(6.5,11),P(8.5,11.6),P(10.5,9),P(10.5,4)]
d.polygon(body,fill=(118,80,58,255))
# shadow on the cheek side
d.polygon([P(8,5),P(10.5,4),P(10.5,9),P(8.5,11.6),P(7.5,9)],fill=(84,54,40,255))
# lit bridge and tip highlight
d.line([P(8.6,0.8),P(5,5.2),P(3,8.4)],fill=(170,124,95,255),width=int(1.3*K))
d.ellipse([P(2.4,8.4)[0],P(2.4,8.4)[1],P(4.4,10.2)[0],P(4.4,10.2)[1]],fill=(160,112,84,255))
# nostril
d.ellipse([P(5,9.6)[0],P(5,9.6)[1],P(7.3,10.9)[0],P(7.3,10.9)[1]],fill=(40,24,18,255))
big=big.filter(ImageFilter.GaussianBlur(K*0.35))
small=big.resize((W,H),Image.LANCZOS)
res=im.copy(); res.alpha_composite(small,(ox-9,oy))
res.save(out)
bg=Image.new("RGBA",res.size,(58,42,30,255)); bg.alpha_composite(res)
bg.convert("RGB").crop((70,55,150,135)).resize((400,400),Image.LANCZOS).save(f"{S}/nose_zoom.png")
