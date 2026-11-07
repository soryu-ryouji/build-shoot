from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
for name,source,accent in [('super_fusion_tower','solar.png',(238,176,62,255)),('super_generator_tower','fusion_tower.png',(255,190,65,255))]:
    base=Image.open(ROOT/'assets'/'ui'/source).convert('RGBA').resize((218,218),Image.Resampling.LANCZOS)
    image=Image.new('RGBA',(256,256),(0,0,0,0));image.alpha_composite(base,(19,19));d=ImageDraw.Draw(image)
    points=[(128,4),(208,32),(252,120),(224,208),(128,252),(32,208),(4,120),(32,32)]
    d.line(points+[points[0]],fill=(42,51,54,255),width=9);d.line(points+[points[0]],fill=accent,width=4)
    for x,y in [(128,8),(224,48),(240,128),(208,208),(48,208),(16,128),(48,48)]:
        d.ellipse((x-6,y-6,x+6,y+6),fill=(248,218,128,255),outline=(61,65,59,255),width=2)
    d.polygon([(112,18),(128,5),(144,18),(139,33),(117,33)],fill=accent)
    image.save(ROOT/'assets'/'ui'/(name+'.png'),optimize=True);image.save(ROOT/'assets'/'ui'/(name+'_field.png'),optimize=True)
print('saved super generator assets')
