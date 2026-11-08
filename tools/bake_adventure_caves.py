"""Hornea una gruta facetada por surface nets; sólo numpy, sin generar mallas al jugar."""
from pathlib import Path
import json
import numpy as np

STEP = 1.0
ORIGIN = np.array([-48., -32., -174.])
SHAPE = (97, 54, 211)
p = np.stack(np.meshgrid(*[ORIGIN[k] + np.arange(SHAPE[k])*STEP for k in range(3)], indexing='ij'), axis=-1)
x,y,z = np.moveaxis(p,-1,0)
# Vestíbulo abierto a +Z; suelo plano y rampa del 17 % hasta la sala mayor.
floor = np.clip((z-18.)*.1875, -18., 0.)
d = np.maximum.reduce([np.abs(x)-3.8, floor-y, y-floor-7.5, -96.-z])
rooms = [(0,-18,-95,14,11),(-24,-18,-132,13,12),(18,-18,-146,13,10),(29,-18,-91,8,7)]
for cx,fy,cz,r,h in rooms:
    dome = (np.sqrt(((x-cx)/r)**2+((z-cz)/r)**2+((y-fy-h*.25)/h)**2)-1)*r
    room = np.maximum(dome,fy-y)
    d=np.minimum(d,room)
paths=[((0,-18,-95),(-24,-18,-132)),((-24,-18,-132),(18,-18,-146)),((18,-18,-146),(0,-18,-95)),((0,-18,-95),(29,-18,-91))]
for a,b in paths:
    a,b=np.array(a,float),np.array(b,float)
    v=(b-a)[[0,2]]
    t=np.clip(((x-a[0])*v[0]+(z-a[2])*v[1])/np.dot(v,v),0,1)
    fx=a[0]+(b[0]-a[0])*t; fz=a[2]+(b[2]-a[2])*t; fy=a[1]+(b[1]-a[1])*t
    tube=np.maximum.reduce([np.sqrt((x-fx)**2+(z-fz)**2)-3.2,fy-y,y-fy-6.5])
    d=np.minimum(d,tube)
# La rugosidad vive en paredes/techo; los suelos no ondulan ni atrapan los pies.
noise=(np.sin(x*.41+z*.23)*np.sin(y*.39-z*.13))*.48
# Sólo mover paredes en alturas separadas de los planos de circulación.
near_floor=np.minimum.reduce([np.abs(y-floor)]+[np.abs(y-r[1]) for r in rooms])
d += noise*np.clip(near_floor/2,0,1)
# La entrada es una trinchera bajo la cota de superficie, no un tubo sobre el prado.
d = np.maximum(d,y+0.4)
corners=np.array([[0,0,0],[1,0,0],[0,1,0],[1,1,0],[0,0,1],[1,0,1],[0,1,1],[1,1,1]])
values=np.stack([d[c[0]:SHAPE[0]-1+c[0],c[1]:SHAPE[1]-1+c[1],c[2]:SHAPE[2]-1+c[2]] for c in corners],-1)
active=(values.min(-1)<=0)&(values.max(-1)>0)
cells=np.argwhere(active)
v=values[active]; sums=np.zeros((len(cells),3)); count=np.zeros(len(cells))
for a in range(8):
 for b in range(a+1,8):
  if np.sum(np.abs(corners[a]-corners[b]))!=1: continue
  cross=(v[:,a]<=0)!=(v[:,b]<=0)
  t=v[cross,a]/(v[cross,a]-v[cross,b])
  sums[cross]+=corners[a]+t[:,None]*(corners[b]-corners[a]);count[cross]+=1
vertices=ORIGIN+(cells+sums/count[:,None])*STEP
lookup=np.full(active.shape,-1,np.int32);lookup[active]=np.arange(len(cells))
triangles=[]
# Cuatro celdas alrededor de cada arista con cambio de signo.
for axis in range(3):
 sl0=[slice(None)]*3;sl1=sl0.copy();sl0[axis]=slice(None,-1);sl1[axis]=slice(1,None)
 edges=np.argwhere((d[tuple(sl0)]<=0)!=(d[tuple(sl1)]<=0))
 other=[k for k in range(3) if k!=axis]
 for e in edges:
  ids=[]
  for u,w in [(0,0),(-1,0),(-1,-1),(0,-1)]:
   c=e.copy();c[other[0]]+=u;c[other[1]]+=w
   if np.any(c<0) or np.any(c>=np.array(active.shape)):break
   ids.append(lookup[tuple(c)])
  if len(ids)!=4 or min(ids)<0:continue
  a,b,c,h=vertices[ids]
  n=np.cross(b-a,c-a)
  # La normal apunta hacia el hueco (campo negativo), para ver desde dentro.
  sign=-1 if d[tuple(e)]>0 else 1
  if n[axis]*sign<0:ids.reverse()
  triangles.extend([[ids[0],ids[1],ids[2]],[ids[0],ids[2],ids[3]]])
faces = vertices[np.asarray(triangles)][:,[0,2,1]]
center = faces.mean(axis=1)
# Quitar sólo la tapa de la trinchera; el resto del techo sigue siendo sólido.
# Todo el vestíbulo abierto pertenece a la rampa con taludes. Cortar aquí
# el SDF evita labios residuales del techo que atrapan la cabeza al salir.
faces = faces[center[:,2]<=-34.0]
points=faces.reshape(-1,3)
Path('generated/caves/cave_surface.json').write_text(json.dumps(points.round(5).tolist(),separators=(',',':')))
print('CAVE BAKE:',len(faces),'triángulos,',len(cells),'celdas de superficie')
