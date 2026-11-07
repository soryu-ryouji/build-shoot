#!/usr/bin/env python3
from pathlib import Path
import json,time,urllib.parse,urllib.request,uuid
from PIL import Image
from generate_ui_assets import api_workflow,request_json,BASE_URL
from process_ui_assets import _cut_chroma
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets'/'ui'/'source'
TARGET=ROOT/'assets'/'ui'
PRESETS={
'coin_tower':(92831,'Single isolated 2D game sprite of a compact coin generator tower for an anime tactical tower defense game, strict orthographic top-down view. Octagonal warm ivory industrial platform with graphite metal machinery, a secure central golden coin minting chamber, three stylized gold coin stacks, small amber status lights, restrained cyan cables, readable symmetrical silhouette, crisp restrained cel shading, detailed clean game asset, centered on a perfectly uniform vivid chroma key green background. No terrain, no text, no letters, no numbers, no UI, no people, no extra objects.'),
'lightning_tower':(92857,'Single isolated 2D game sprite of an experimental lightning cannon for an anime tactical tower defense game, strict orthographic top-down view. Octagonal warm ivory armor base with graphite mechanisms, twin copper induction coils surrounding a raised cyan-white plasma orb, short insulated conductors, small signal orange warning marks, readable symmetrical silhouette, no lightning outside the machine, crisp restrained cel shading, detailed clean game asset, centered on a perfectly uniform vivid chroma key green background. No terrain, no text, no letters, no numbers, no UI, no people, no extra objects.')}

def generate(name,seed,prompt):
    preset={'prompt':prompt,'seed':seed,'landscape':False,'width':1024,'height':1024}
    result=request_json('/prompt',{'prompt':api_workflow(preset,'build_shoot/'+name),'client_id':str(uuid.uuid4())})
    pid=result['prompt_id'];print(name,'queued',pid,flush=True)
    while pid not in request_json('/history/'+pid):time.sleep(2)
    entry=request_json('/history/'+pid)[pid]
    images=[]
    for output in entry.get('outputs',{}).values():images.extend(output.get('images',[]))
    if not images:raise RuntimeError(name+' produced no image')
    image=images[0];query=urllib.parse.urlencode({'filename':image['filename'],'subfolder':image.get('subfolder',''),'type':image.get('type','output')})
    with urllib.request.urlopen(BASE_URL+'/view?'+query,timeout=60) as response:content=response.read()
    SOURCE.mkdir(parents=True,exist_ok=True);(SOURCE/(name+'.png')).write_bytes(content)
    cut=_cut_chroma(Image.open(SOURCE/(name+'.png')));bounds=cut.getchannel('A').getbbox();cut=cut.crop(bounds)
    side=max(cut.size)+48;canvas=Image.new('RGBA',(side,side),(0,0,0,0));canvas.paste(cut,((side-cut.width)//2,(side-cut.height)//2),cut);canvas=canvas.resize((256,256),Image.Resampling.LANCZOS)
    canvas.save(TARGET/(name+'.png'),optimize=True);canvas.save(TARGET/(name+'_field.png'),optimize=True)
    print(name,'processed',flush=True)
for name,(seed,prompt) in PRESETS.items():generate(name,seed,prompt)
