import numpy as np, sys
from PIL import Image, ImageDraw, ImageFilter
W,H=[int(x) for x in sys.argv[1:3]]; out=sys.argv[3]
S=2  # supersample
w,h=W*S,H*S
# background gradient
y=np.linspace(0,1,h)[:,None]
top=np.array([15,75,90]); mid=np.array([8,39,51]); bot=np.array([4,13,18])
t=np.clip(y/0.52,0,1); t2=np.clip((y-0.52)/0.48,0,1)
col=np.where(y<0.52, top*(1-t)+mid*t, mid*(1-t2)+bot*t2)
img=np.repeat(col[:,:,None],w,axis=1).transpose(0,1,2) if False else np.broadcast_to(col[:,None,:],(h,w,3)).copy()
# glow at the top
xx=np.linspace(-1,1,w)[None,:]; yy=np.linspace(0,1,h)[:,None]
glow=np.exp(-((xx/0.65)**2+((yy+0.05)/0.45)**2))
img+= glow[:,:,None]*np.array([40,70,78])*0.55
# glow on the horizon
hor=0.60
g2=np.exp(-((yy-hor)/0.05)**2)*np.exp(-(xx/0.9)**2)
img+= g2[:,:,None]*np.array([30,90,100])*0.35
base=Image.fromarray(np.clip(img,0,255).astype('uint8'),'RGB').convert('RGBA')
lay=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(lay)
# vertical grid at the top (IFSCL)
for i,x in enumerate(np.arange(0,W,160)[1:]):
    for yy_ in range(0,int(hor*H*S),2):
        a=int(95*(1-yy_/(hor*H*S))**1.4)
        d.point((x*S,yy_),fill=(143,220,245,a)); d.point((x*S+1,yy_),fill=(143,220,245,a))
for yv,a in [(0.13,70),(0.31,40),(0.5,18)]:
    d.line([(0,yv*h),(w,yv*h)],fill=(143,220,245,a),width=S)
# wireframe terrain in perspective
rng=np.random.default_rng(7)
nx,nz=46,26
X=np.linspace(-2.6,2.6,nx); Z=np.linspace(1.2,9,nz)
# relief: gentle hills plus peaks
Hm=np.zeros((nz,nx))
for _ in range(9):
    cx,cz=rng.uniform(-2.4,2.4),rng.uniform(3,9); r=rng.uniform(0.5,1.3); a=rng.uniform(0.2,0.9)
    Hm+=a*np.exp(-(((X[None,:]-cx)**2+(Z[:,None]-cz)**2)/r**2))
Hm+=0.06*rng.standard_normal(Hm.shape)
Hm*= np.clip(np.abs(X[None,:])/1.2,0.25,1.0)  # valley down the middle
camy=0.9
def proj(x,yv,z):
    f=1.25*H
    return (W/2+x/z*f*0.95)*S, (hor*H + (camy-yv)/z*f*0.55)*S
pts=np.zeros((nz,nx,2))
for j in range(nz):
    for i in range(nx):
        pts[j,i]=proj(X[i],Hm[j,i],Z[j])
def fade(j): return (1-j/(nz-1))**1.3
for j in range(nz):
    a=int(150*fade(j)); c=(80,215,235,a)
    for i in range(nx-1): d.line([tuple(pts[j,i]),tuple(pts[j,i+1])],fill=c,width=S)
for i in range(nx):
    for j in range(nz-1):
        a=int(130*fade(j)); d.line([tuple(pts[j,i]),tuple(pts[j+1,i])],fill=(80,215,235,a),width=S)
for j in range(nz-1):
    for i in range(nx-1):
        if (i+j)%2==0:
            a=int(55*fade(j)); d.line([tuple(pts[j,i]),tuple(pts[j+1,i+1])],fill=(80,215,235,a),width=S)
# lit summits
for j in range(0,nz,3):
    for i in range(0,nx,5):
        if Hm[j,i]>0.55:
            x_,y_=pts[j,i]; r=2*S; d.ellipse([x_-r,y_-r,x_+r,y_+r],fill=(255,190,90,int(180*fade(j))))
glowL=lay.filter(ImageFilter.GaussianBlur(4*S))
base=Image.alpha_composite(base,glowL); base=Image.alpha_composite(base,lay)
# vignette
v=np.clip(1-0.45*(xx**2)*np.ones((h,1)),0,1)
arr=np.array(base).astype(float); arr[:,:,:3]*=v[:,:,None]; base=Image.fromarray(arr.astype('uint8'),'RGBA')
base=base.resize((W,H),Image.LANCZOS).convert('RGB')
base.save(out,quality=92) if out.endswith('.jpg') else base.save(out,optimize=True)
