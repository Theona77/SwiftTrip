import sys; sys.path.insert(0, sys.argv[1]); from svgkit import *
d=Doc(1780,850)
d.title('SwiftTrip — UI State Machine (UML)','UI/UX design: every screen (state) and the user action (transition) that moves between them')
def st(cx,cy,name,w=150,h=52,col=BLUE,sub=None):
    d.rect(cx-w/2,cy-h/2,w,h,col,rx=16)
    if sub: d.text(cx,cy-3,name,14,700); d.text(cx,cy+15,sub,11.5,400,SUB)
    else: d.text(cx,cy+5,name,14,700)
def init(x,y): d.add(f'<circle cx="{x}" cy="{y}" r="9" fill="{INK}"/>')
def final(x,y): d.add(f'<circle cx="{x}" cy="{y}" r="11" fill="#fff" stroke="{INK}" stroke-width="2"/><circle cx="{x}" cy="{y}" r="6" fill="{INK}"/>')
SH=('#F7F8FA','#9AA1AD')
# sheets row
for cx,n,sub in [(600,'Add Trip','sheet'),(800,'Add Category','sheet'),(960,'Edit Date','sheet'),(1140,'Select mode','multi-select'),(1400,'Edit Information','sheet')]:
    st(cx,150,n,140 if cx!=1400 else 160,50,SH,sub)
# main row
st(600,290,'Home',150,52,BLUE,'Essentials · Trips · Recents')
st(880,290,'Trip',150,52,BLUE,'categories · dates · search')
st(1140,290,'Category',150,52,BLUE,'document grid')
st(1400,290,'Document detail',170,52,BLUE,'fields · notes')
st(1640,290,'Full-screen viewer',210,52,PURPLE,'pinch / double-tap zoom · pages')
# launch
init(60,285); d.add(f'<path d="M150,267 L168,285 L150,303 L132,285 Z" fill="#fff" stroke="{INK}" stroke-width="1.6"/>')
d.path('M69,285 H130'); d.path('M168,285 H523'); d.label(330,277,'[hasOnboarded]')
# onboarding composite
d.rect(40,370,380,110,('#FFFFFF','#3478F6'),rx=14); d.text(56,392,'Onboarding',13.5,700,anchor='start')
st(140,435,'Access Anytime',150,40,BLUE); st(320,435,'Store & Access',150,40,BLUE)
d.path('M215,435 H243'); d.label(229,425,'Next',11)
d.path('M150,303 V368'); d.label(150,340,'[first launch]')
d.path('M420,380 L524,305'); d.label(462,330,'Get Started')
# recent
st(330,585,'Recent document',170,52,BLUE,'from Recently viewed')
d.path('M540,316 L370,558'); d.label(470,470,'tap recent',12)
# bidir vertical sheets
def bidir(x,y1,y2,l):
    d.path(f'M{x},{y1} V{y2}',start='arrow'); d.label(x,y1+28,l,11.5)
bidir(600,177,262,'Add Trip ⇄ Create · Cancel')
bidir(800,177,262,'Add Category ⇄ Add')
bidir(960,177,262,'tap date ⇄ Done')
bidir(1140,177,262,'long-press ⇄ Delete · Cancel')
bidir(1400,177,262,'Edit ⇄ Save · Cancel')
# horizontal nav
d.path('M675,290 H803'); d.label(739,282,'tap trip card',11.5)
d.path('M955,290 H1063'); d.label(1009,282,'tap category',11.5)
d.path('M1215,280 H1313'); d.label(1264,272,'tap document',11.5)
d.path('M1313,302 H1217'); d.label(1264,318,'Delete Document',11.5)
d.path('M1485,280 H1533'); d.path('M1533,302 H1487'); d.label(1509,272,'tap image',11); d.label(1509,318,'Close',11)
d.path('M948,264 V240 H1372 V262'); d.label(1260,244,'tap search result',11.5)
# essentials
st(1140,420,'Essentials category',190,52,BLUE,'Passport · ID · VISA')
d.path('M655,316 V420 H1043'); d.label(820,412,'tap Passport / ID / VISA',11.5)
d.path('M1235,420 H1400 V318'); d.label(1320,412,'tap document',11.5)
# scan composite
d.rect(470,500,1060,200,('#FFFFFF','#6E56CF'),rx=14,sw=1.8); d.text(488,524,'Scan flow  (sheet, ScanFlowCoordinator)',13.5,700,anchor='start')
Y=610
init(510,Y); d.path(f'M519,{Y} H553')
st(630,Y,'Source picker',150,48,PURPLE,'camera · photos · files')
d.path(f'M705,{Y} H753'); d.label(729,Y-30,'pick',11)
st(830,Y,'Processing',150,48,PURPLE,'OCR + rules')
d.path(f'M905,{Y} H963'); d.label(934,Y-30,'result (instant)',11)
st(1040,Y,'Confirm',150,48,PURPLE,'category + fields')
d.path(f'M1010,{Y-24} C1010,{Y-70} 1070,{Y-70} 1070,{Y-26}'); d.label(1040,Y-62,'AI refinement arrives',11)
d.path(f'M1000,{Y+24} C980,{Y+70} 870,{Y+70} 850,{Y+26}'); d.label(925,Y+64,'Retake',11)
d.path(f'M1115,{Y} H1163'); d.label(1139,Y-30,'Save',11)
st(1240,Y,'Details',150,48,PURPLE,'trip / Essentials')
d.path(f'M1315,{Y} H1353'); d.label(1336,Y-30,'Save',11)
st(1410,Y,'Saved',100,48,PURPLE)
d.path(f'M1460,{Y} H1478'); final(1490,Y)
d.path(f'M1080,{Y+24} C1110,{Y+82} 1460,{Y+82} 1488,{Y+13}'); d.label(1290,Y+77,'Discard last',11)
d.path('M620,316 V498'); d.label(620,470,'Scan button',11.5)
d.path('M880,316 V498'); d.label(880,470,'Scan button',11.5)
d.path('M575,500 V318'); d.label(560,470,'dismiss',11,anchor='end')
# recent -> viewer
d.path('M330,611 V780 H1640 V318'); d.label(1000,772,'tap image',11.5)
# widget entry
init(1690,150); d.text(1674,145,'Widget tap',13,700,anchor='end'); d.text(1674,163,'(Home Screen)',11.5,400,SUB,anchor='end')
d.path('M1690,159 V200 L1460,262'); d.label(1580,222,'hh://document/…',11)
# legend
d.rect(40,690,230,130,GRAY,rx=10)
init(62,715); d.text(80,720,'start',12,400,SUB,anchor='start')
d.add(f'<path d="M62,734 L74,746 L62,758 L50,746 Z" fill="#fff" stroke="{INK}" stroke-width="1.4"/>'); d.text(80,751,'choice [guard]',12,400,SUB,anchor='start')
final(62,782); d.text(80,787,'end of flow',12,400,SUB,anchor='start')
d.text(50,810,'grey = sheet · purple = scan flow',11.5,400,SUB,anchor='start')
d.render(sys.argv[2])
