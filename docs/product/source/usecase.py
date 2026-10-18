import sys; sys.path.insert(0, sys.argv[1]); from svgkit import *
d=Doc(1600,1010)
d.title('SwiftTrip — Use Case Diagram','Product description: who uses SwiftTrip and what they can do')
d.rect(230,110,1170,870,('#FFFFFF','#9AA1AD'),rx=14,sw=2)
d.text(250,138,'SwiftTrip  «system»  iPhone app + Home Screen widget',15,700,anchor='start')
L=440; RX=128
left=[(185,['Get started','(onboarding)']),(275,['Create & edit trip']),(365,['Manage trip categories']),(480,['Add document']),
      (650,['Find document','(search · recently viewed)']),(740,['View document','(zoom · PDF pages)']),(830,['Edit / delete documents']),(920,['Open next document','from widget'])]
# traveler
d.actor(110,520,['Traveler'])
for y,_ in left: d.path(f'M138,505 L{L-RX+4},{y}',end=None)
for y,t in left: d.ellipse(L,y,RX,34,t,BLUE,14)
# middle
M=830
mid=[(170,['Read text','(OCR + MRZ)']),(290,['Classify document']),(410,['Review & edit details'])]
for y,t in mid: d.ellipse(M,y,RX,34,t,BLUE,14)
for (y,_),lx,ly in zip(mid,[600,640,650],[260,350,430]):
    d.path(f'M{L+RX-30},{480-24} L{M-RX+8},{y+(12 if y<480 else 0)}',dash=True,end='open')
d.label(610,300,'«include»'); d.label(660,372,'«include»'); d.label(650,440,'«include»')
# generalisations
kids=[(580,['Scan with camera']),(670,['Import photo']),(760,['Import PDF / file'])]
for y,t in kids:
    d.ellipse(M,y,112,30,t,BLUE,14)
    d.path(f'M{M-112},{y} L{L+RX-6},{480+10}',end='tri')
d.label(705,560,'generalization',12)
# right column
R=1190
d.ellipse(R,410,150,38,['File into trip or','Personal Essentials'],BLUE,14)
d.path(f'M{M+RX},{410} L{R-150},{410}',dash=True,end='open'); d.label(1000,402,'«include»')
d.ellipse(R,270,150,38,['Refine with','Apple Intelligence'],PURPLE,14)
d.path(f'M{R-150+6},{280} L{M+RX-6},{292}',dash=True,end='open'); d.label(1010,270,'«extend»')
d.note(975,186,300,44,'',[])
d.text(989,204,'condition: rules unsure, "Others",',12.5,600,anchor='start'); d.text(989,221,'or key fields missing',12.5,600,anchor='start')
d.path('M1030,230 L1010,262',dash=True,end=None,color='#C9A227',sw=1.2)
# widget include view
d.path(f'M{L+RX},{915} C{L+RX+90},{890} {L+RX+90},{765} {L+RX+4},{748}',dash=True,end='open'); d.label(L+RX+70,835,'«include»')
# secondary actor
d.actor(1500,190,['Apple on-device AI','(Vision · Foundation','Models)'])
d.path(f'M1472,175 L{M+RX},{170}',end=None); d.path(f'M1472,182 L{R+150-4},{262}',end=None)
# legend
lx,ly=1090,770
d.rect(lx,ly,290,180,GRAY,rx=10)
d.text(lx+16,ly+26,'Legend',14,700,anchor='start')
d.path(f'M{lx+18},{ly+52} H{lx+78}',end=None); d.text(lx+92,ly+57,'association (actor uses)',13,400,SUB,anchor='start')
d.path(f'M{lx+18},{ly+84} H{lx+78}',dash=True,end='open'); d.text(lx+92,ly+89,'«include» / «extend»',13,400,SUB,anchor='start')
d.path(f'M{lx+18},{ly+116} H{lx+78}',end='tri'); d.text(lx+92,ly+121,'generalization (kind of)',13,400,SUB,anchor='start')
d.add(f'<ellipse cx="{lx+48}" cy="{ly+152}" rx="30" ry="12" fill="{PURPLE[0]}" stroke="{PURPLE[1]}"/>'); d.text(lx+92,ly+157,'optional (Apple Intelligence)',13,400,SUB,anchor='start')
d.render(sys.argv[2])
