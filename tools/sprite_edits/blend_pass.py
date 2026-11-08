# Light img2img pass over a hand-edited attack sprite: keeps the layout, smooths seams.
# usage: blend.py <hero> <in.png> <out_prefix> <strength> <seed>...
import sys, json
sys.path.insert(0, "tools")
import sd_sprites as sp
from PIL import Image
hero, src, outp, strength = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
seeds = [int(x) for x in sys.argv[5:]]
m = json.load(open("tools/art_manifest.json")); cfg = m["sprites"]
c = [x for x in cfg["characters"] if x["id"] == hero][0]
pipes, dev, torch = sp.load_pipelines(m["model"], cfg["control_model"], cfg.get("reference"))
pipes["txt"].set_ip_adapter_scale(0.6)
w, h = cfg["size"]
im = Image.open(src).convert("RGBA")
bg = Image.new("RGBA", im.size, (128, 128, 128, 255)); bg.alpha_composite(im)
init = bg.convert("RGB").resize((w, h), Image.LANCZOS)
ref = sp.sprite_reference(hero, "idle")
prompt = sp.redo_prompt(cfg, m, c, "attack")
neg = (c.get("negative_extra", "") + ", " + cfg["negative"]).strip(", ")
from rembg import new_session, remove
sess = new_session(cfg.get("cutout_model", "isnet-general-use"))
for sd in seeds:
    img = pipes["img"](prompt=prompt, image=init, strength=strength, negative_prompt=neg,
                       num_inference_steps=int(cfg["steps"]), guidance_scale=float(m["cfg_scale"]),
                       generator=torch.Generator(device="cpu").manual_seed(sd), ip_adapter_image=ref).images[0]
    cut = remove(img.resize(im.size, Image.LANCZOS), session=sess)
    cut.save(f"{outp}_{sd}.png"); print("saved", f"{outp}_{sd}.png", flush=True)
