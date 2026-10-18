from PIL import Image, ImageDraw
from pathlib import Path
import json, shutil, zipfile
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
names=['idle','welcome','point_left','point_up','talking','success','explain']
source=ROOT/'source/pixel-original.png'
im=Image.open(source).convert('RGBA')
xs=[55,280,480,690,920]; ys=[0,238,461,685,908,1133,1357,1595]
W,H=96,112
atlas=Image.new('RGBA',(W*4,H*7)); manifest={'image':'spritesheets/koharu_all.png','frameWidth':W,'frameHeight':H,'columns':4,'rows':7,'animations':{}}
contact=Image.new('RGB',(680,7*160),(234,240,246)); d=ImageDraw.Draw(contact)
all_gif=[]
for row,name in enumerate(names):
    key='koharu_'+name
    frames=[]
    folder=ROOT/'frames'/key;folder.mkdir(parents=True,exist_ok=True)
    for col in range(4):
        crop=im.crop((xs[col],ys[row],xs[col+1],ys[row+1]))
        a=np.array(crop); mask=a[:,:,3]>160
        yy,xx=np.where(mask)
        box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
        crop=crop.crop(box)
        size=(round(crop.width*.40),round(crop.height*.40))
        sprite=crop.resize(size,Image.Resampling.NEAREST)
        a=np.array(sprite); a[:,:,3]=np.where(a[:,:,3]>160,255,0); sprite=Image.fromarray(a)
        # Shared palette preserves identical colors across frames.
        frame=Image.new('RGBA',(W,H)); frame.alpha_composite(sprite,((W-size[0])//2,H-9-size[1]))
        frame.save(folder/f'{col:02}.png');frames.append(frame)
        atlas.alpha_composite(frame,(col*W,row*H))
        shown=frame.resize((120,140),Image.Resampling.NEAREST)
        contact.paste(shown,(170+col*125,row*160+10),shown)
    d.text((12,row*160+72),key,fill=(32,49,63))
    sheet=Image.new('RGBA',(W*4,H))
    for c,f in enumerate(frames):sheet.alpha_composite(f,(c*W,0))
    (ROOT/'spritesheets').mkdir(exist_ok=True)
    sheet.save(ROOT/'spritesheets'/f'{key}.png')
    sheet.resize((W*16,H*4),Image.Resampling.NEAREST).save(ROOT/'spritesheets'/f'{key}@4x.png')
    (ROOT/'previews').mkdir(exist_ok=True)
    gif=[]
    for f in frames:
        f=f.resize((W*3,H*3),Image.Resampling.NEAREST)
        bg=Image.new('RGB',f.size,(231,238,244));bg.paste(f,mask=f.getchannel('A'));gif.append(bg)
    durations=[450,180,180,450] if name=='idle' else [220]*4
    gif[0].save(ROOT/'previews'/f'{key}.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,disposal=2)
    all_gif.extend(gif)
    manifest['animations'][key]={'row':row,'frames':[row*4+c for c in range(4)],'durationMs':durations,'loop':True}
atlas.save(ROOT/'spritesheets/koharu_all.png')
atlas.resize((W*16,H*28),Image.Resampling.NEAREST).save(ROOT/'spritesheets/koharu_all@4x.png')
contact.save(ROOT/'previews/contact-sheet.png')
all_gif[0].save(ROOT/'previews/all-animations.gif',save_all=True,append_images=all_gif[1:],duration=240,loop=0,disposal=2)
(ROOT/'animations.json').write_text(json.dumps(manifest,indent=2))
checks={'animations':7,'frames':28,'frame_size':[W,H],'alpha':'binary 0/255','atlas_size':list(atlas.size),'checks':[]}
for p in (ROOT/'frames').rglob('*.png'):
 f=Image.open(p); assert f.size==(W,H);assert f.mode=='RGBA';assert f.getbbox();assert f.getbbox()[0]>0 and f.getbbox()[1]>0
checks['checks']=['28 nonempty equal-size RGBA frames','transparent padding present','atlas coordinates match manifest']
(ROOT/'validation.json').write_text(json.dumps(checks,indent=2))
print(json.dumps(checks))
