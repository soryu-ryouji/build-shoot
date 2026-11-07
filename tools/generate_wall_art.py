from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'ui'
S=256

def tile(mask):
    rng=random.Random(7400+mask)
    shape=Image.new('L',(S,S),0)
    d=ImageDraw.Draw(shape)
    d.rounded_rectangle((32,32,224,224),radius=16,fill=255)
    if mask&1:d.rectangle((80,0,176,70),fill=255)
    if mask&2:d.rectangle((186,80,256,176),fill=255)
    if mask&4:d.rectangle((80,186,176,256),fill=255)
    if mask&8:d.rectangle((0,80,70,176),fill=255)
    image=Image.new('RGBA',(S,S),(0,0,0,0))
    shadow=Image.new('RGBA',(S,S),(12,18,21,0))
    shadow.putalpha(shape.filter(ImageFilter.GaussianBlur(3)).point(lambda a:a*35//100))
    layer=Image.new('RGBA',(S,S),(0,0,0,0));layer.paste(shadow,(4,6),shadow);image.alpha_composite(layer)
    border=Image.new('RGBA',(S,S),(47,55,59,255));border.putalpha(shape.filter(ImageFilter.MaxFilter(9)));image.alpha_composite(border)
    body=Image.new('RGBA',(S,S),(0,0,0,0));bp=body.load();mp=shape.load()
    for y in range(S):
        for x in range(S):
            if mp[x,y]:
                n=rng.randrange(-7,8)+int(8*(1-y/S));bp[x,y]=(157+n,160+n,154+n,255)
    image.alpha_composite(body)
    eroded=shape.filter(ImageFilter.MinFilter(9));edge=Image.new('L',(S,S),0);ep=edge.load();rp=eroded.load()
    for y in range(S):
        for x in range(S):ep[x,y]=100 if mp[x,y] and not rp[x,y] else 0
    bevel=Image.new('RGBA',(S,S),(225,224,207,0));bevel.putalpha(edge);image.alpha_composite(bevel)
    d=ImageDraw.Draw(image)
    # Reinforcement strips remain continuous across cell boundaries.
    if mask&10:
        d.rectangle((32,112,224,142),fill=(64,76,79,255));d.rectangle((32,117,224,123),fill=(103,157,159,255))
        if mask&2:d.rectangle((182,80,256,176),fill=(140,146,141,255));d.rectangle((182,112,256,142),fill=(64,76,79,255));d.rectangle((182,117,256,123),fill=(103,157,159,255))
        if mask&8:d.rectangle((0,80,74,176),fill=(140,146,141,255));d.rectangle((0,112,74,142),fill=(64,76,79,255));d.rectangle((0,117,74,123),fill=(103,157,159,255))
    if mask&5:
        d.rectangle((112,32,142,224),fill=(64,76,79,255));d.rectangle((117,32,123,224),fill=(103,157,159,255))
        if mask&1:d.rectangle((80,0,176,74),fill=(140,146,141,255));d.rectangle((111,0,143,74),fill=(64,76,79,255));d.rectangle((117,0,124,74),fill=(103,157,159,255))
        if mask&4:d.rectangle((80,182,176,256),fill=(140,146,141,255));d.rectangle((111,182,143,256),fill=(64,76,79,255));d.rectangle((117,182,124,256),fill=(103,157,159,255))
    d.rounded_rectangle((66,66,190,190),radius=10,fill=(132,139,136,255),outline=(57,68,71,255),width=4)
    d.rounded_rectangle((82,82,174,174),radius=8,fill=(153,157,148,255),outline=(190,188,169,255),width=3)
    d.line((94,157,162,94),fill=(198,190,164,255),width=4)
    for x,y in ((50,50),(206,50),(50,206),(206,206)):
        d.ellipse((x-7,y-7,x+7,y+7),fill=(43,53,56,255),outline=(200,195,174,255),width=2)
    return image

atlas=Image.new('RGBA',(S*4,S*4),(0,0,0,0))
for mask in range(16):atlas.paste(tile(mask),((mask%4)*S,(mask//4)*S))
OUT.mkdir(parents=True,exist_ok=True)
atlas.save(OUT/'wall_field.png',optimize=True)
tile(0).save(OUT/'wall.png',optimize=True)
print('saved wall atlas and icon')
