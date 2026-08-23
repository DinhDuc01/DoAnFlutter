from pathlib import Path
from PIL import Image, ImageDraw

out_dir = Path(r"D:\DoAnFlutter\work\testdoc_pages2")
paths = sorted(out_dir.glob("page-*.png"))
thumbs = []
for i, path in enumerate(paths):
    im = Image.open(path).convert("RGB")
    im.thumbnail((500, 650))
    canvas = Image.new("RGB", (520, 690), "white")
    canvas.paste(im, ((520-im.width)//2, 25))
    ImageDraw.Draw(canvas).text((10, 5), f"Page {i+1}", fill="black")
    thumbs.append(canvas)
for start in range(0, len(thumbs), 6):
    batch = thumbs[start:start+6]
    sheet = Image.new("RGB", (1040, 690*((len(batch)+1)//2)), "#dddddd")
    for j, im in enumerate(batch):
        sheet.paste(im, ((j%2)*520, (j//2)*690))
    sheet.save(out_dir / f"contact-{start//6+1}.png")
print(f"pages={len(paths)} contacts={(len(thumbs)+5)//6}")
