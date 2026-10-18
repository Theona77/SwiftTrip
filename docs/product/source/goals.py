import sys; sys.path.insert(0, sys.argv[1]); from svgkit import *
d=Doc(1600,1060)
d.title('SwiftTrip — Goals & Strategy (SysML requirement diagram)','Traceability: product vision → goals → strategy → the features that deliver it')
def req(x,y,w,h,stereo,ident,name,body,col):
    d.rect(x,y,w,h,col,rx=8)
    d.add(f'<line x1="{x}" y1="{y+52}" x2="{x+w}" y2="{y+52}" stroke="{col[1]}" stroke-width="1.2"/>')
    d.text(x+w/2,y+20,f'«{stereo}»',12,500,SUB); d.text(x+w/2,y+40,f'{ident}  {name}',14.5,700)
    for i,l in enumerate(body): d.text(x+12,y+74+i*19,l,13,400,SUB,anchor='start')
# band labels
for y,t in [(150,'PRODUCT'),(380,'GOALS'),(620,'STRATEGY'),(860,'FEATURES')]:
    d.add(f'<text x="22" y="{y}" font-size="12" font-weight="700" fill="#9AA1AD" letter-spacing="1.5" transform="rotate(-90 22 {y})" text-anchor="middle">{t}</text>')
# product notes + vision
d.note(44,108,360,128,'Problem',['Travel documents are scattered across email,','screenshots, PDFs and chat apps, and are hard','to find at the gate, border or check-in —','often with no signal.'])
d.note(420,108,330,128,'Target users',['Travellers: holidaymakers, frequent','and business travellers, families','managing several people\'s documents.'])
req(780,104,400,140,'requirement','G0','Product vision',['Travellers reach any travel document','in seconds, anywhere — even offline.','verify: demonstration'],BLUE)
d.note(1200,108,356,128,'Value proposition',['One place for every travel document,','sorted automatically by trip, one tap','from the Home Screen, private by design','(nothing leaves the iPhone).'])
# goals
cols=[40+i*385 for i in range(4)]; W=365
goals=[('G1','One place',['Every travel document stored in','one app, organized by trip.','verify: demonstration']),
       ('G2','Fast access',['The right document in one or two','taps at the airport, border, hotel.','verify: test (widget, search)']),
       ('G3','Effortless capture',['Little to no manual sorting or','typing when adding documents.','verify: test (classification)']),
       ('G4','Private & offline',['Passports and IDs never leave','the device; works with no signal.','verify: inspection (no network)'])]
for x,(i,n,b) in zip(cols,goals): req(x,320,W,128,'requirement',i,n,b,BLUE)
for k,x in enumerate(cols):
    sx=900+(k-1.5)*70
    d.path(f'M{sx},244 C{sx},285 {x+W/2},280 {x+W/2},318',end=None,start='cplus')
d.label(1265,282,'contains',12)
# strategy (aligned with goals)
strat=[('S1','Trip-centric organization',['Trips with preset categories; status','(upcoming / ongoing / completed);','Personal Essentials outside trips.']),
       ('S3','Right document, right time',['Surface what\'s needed next by date;','one-tap widget, search, recents,','full-screen zoom for QR codes.']),
       ('S2','Capture once, understand it',['Scan or import; read text on device;','classify + extract fields; user only','confirms or corrects.']),
       ('S4','On-device & offline first',['No accounts, no backend, no SDKs;','Vision, Core ML, Foundation Models','run locally; data in app storage.'])]
for x,(i,n,b) in zip(cols,strat):
    req(x,560,W,128,'designConstraint',i,n,b,PURPLE)
    d.path(f'M{x+W/2},560 V452',dash=True,end='open'); d.label(x+W/2,512,'«refine»',12)
# features
feats=[[('F1','Trip cards'),('F2','Personal Essentials')],
       [('F5','Widget'),('F6','Find & zoom')],
       [('F3','Scan & import'),('F4','Smart reading')],
       [('F7','Local JSON · privacy manifests')]]
fdesc={'F1':['preset categories, status,','TripScreen · CategoryScreen'],'F2':['globalCategories:','Passport · ID · VISA'],
       'F5':['SharedDocumentStore','pickNextDocument()'],'F6':['search, Recently viewed,','FullImageViewer (zoom)'],
       'F3':['camera · Photos · Files (PDF)','ScanFlowLauncher'],'F4':['OCR · MRZ · classifier ·','Foundation Models assist'],
       'F7':['home_state.json, Documents/,','PrivacyInfo.xcprivacy (Data Not Collected)']}
for x,group in zip(cols,feats):
    n=len(group); fw=(W-(n-1)*12)/n
    for j,(i,name) in enumerate(group):
        fx=x+j*(fw+12)
        d.rect(fx,800,fw,118,GREEN,rx=8)
        d.text(fx+fw/2,820,'«block» feature',12,500,SUB); d.text(fx+fw/2,840,f'{i}  {name}',13.5,700)
        d.add(f'<line x1="{fx}" y1="852" x2="{fx+fw}" y2="852" stroke="{GREEN[1]}" stroke-width="1.2"/>')
        for k,l in enumerate(fdesc[i]): d.text(fx+fw/2,876+k*18,l,12,400,SUB)
        d.path(f'M{fx+fw/2},800 V692',dash=True,end='open')
    d.label(x+W/2,748,'«satisfy»',12)
# legend
ly=950
d.rect(40,ly,1520,70,GRAY,rx=10)
items=[('cplus','contains — goal is part of the vision'),('refine','«refine» — strategy details how a goal is met'),('satisfy','«satisfy» — feature implements the strategy')]
x=60
for kind,txt in items:
    if kind=='cplus': d.path(f'M{x+50},{ly+35} H{x}',end=None,start='cplus')
    else: d.path(f'M{x},{ly+35} H{x+50}',dash=True,end='open')
    d.text(x+72,ly+40,txt,13,400,SUB,anchor='start'); x+=470
d.render(sys.argv[2])
