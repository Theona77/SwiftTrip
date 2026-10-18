# Tiny SVG helper for the product UML diagrams in docs/product/.
# Usage: python3 usecase.py <this folder> <output.png>   (needs Chrome or Chromium + Pillow)
import html, math, subprocess
INK='#1C1E21'; SUB='#4B5260'; LINE='#5B6270'
BLUE=('#EAF1FE','#3478F6'); ORANGE=('#FFF3E6','#E8830C'); PURPLE=('#F1EEFD','#6E56CF')
TEAL=('#E7F6F8','#1F8FA3'); GREEN=('#E9F7EE','#2E9E57'); GRAY=('#F1F2F4','#6B7280')
class Doc:
    def __init__(s,W,H): s.W,s.H=W,H; s.o=[]
    def add(s,x): s.o.append(x)
    def text(s,x,y,txt,size=14,w=400,fill=INK,anchor='middle',italic=False):
        st=' font-style="italic"' if italic else ''
        s.add(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{w}" fill="{fill}" text-anchor="{anchor}"{st}>{html.escape(txt)}</text>')
    def lines(s,x,y,lst,size=14,w=400,fill=INK,anchor='middle',lh=None):
        lh=lh or size*1.3; y0=y-(len(lst)-1)*lh/2+size*0.35
        for i,l in enumerate(lst): s.text(x,y0+i*lh,l,size,w,fill,anchor)
    def title(s,t,sub):
        s.text(40,52,t,28,700,anchor='start'); s.text(40,80,sub,15,400,SUB,anchor='start')
    def rect(s,x,y,w,h,col=BLUE,rx=10,sw=1.5,dash=False):
        d=' stroke-dasharray="6 4"' if dash else ''
        s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{col[0]}" stroke="{col[1]}" stroke-width="{sw}"{d}/>')
    def ellipse(s,cx,cy,rx,ry,lst,col=BLUE,size=14):
        s.add(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{col[0]}" stroke="{col[1]}" stroke-width="1.5"/>')
        s.lines(cx,cy,lst,size)
    def path(s,d,dash=False,end='arrow',start=None,color=LINE,sw=1.6):
        da=' stroke-dasharray="6 5"' if dash else ''
        me=f' marker-end="url(#{end})"' if end else ''
        ms=f' marker-start="url(#{start})"' if start else ''
        s.add(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}"{da}{me}{ms}/>')
    def label(s,x,y,txt,size=12.5,anchor='middle',fill='#3A404C',bg='#FFFFFF'):
        w=len(txt)*size*0.56+10
        bx={'middle':x-w/2,'start':x,'end':x-w}[anchor]
        s.add(f'<rect x="{bx}" y="{y-size*0.95}" width="{w}" height="{size*1.45}" rx="4" fill="{bg}" opacity="0.92"/>')
        s.text(bx+w/2,y,txt,size,500,fill)
    def actor(s,x,y,lst,col=ORANGE[1]):
        s.add(f'<g stroke="{col}" stroke-width="2.4" fill="none" stroke-linecap="round"><circle cx="{x}" cy="{y-38}" r="13" fill="#FFF3E6"/><path d="M{x},{y-25} V{y+12} M{x-24},{y-12} H{x+24} M{x},{y+12} L{x-18},{y+40} M{x},{y+12} L{x+18},{y+40}"/></g>')
        s.lines(x,y+66,lst,14,600,lh=18)
    def note(s,x,y,w,h,head,lst,col=('#FFFBEA','#C9A227')):
        f=16
        s.add(f'<path d="M{x},{y} H{x+w-f} L{x+w},{y+f} V{y+h} H{x} Z" fill="{col[0]}" stroke="{col[1]}" stroke-width="1.4"/><path d="M{x+w-f},{y} V{y+f} H{x+w}" fill="none" stroke="{col[1]}" stroke-width="1.4"/>')
        s.text(x+14,y+24,head,13.5,700,anchor='start')
        for i,l in enumerate(lst): s.text(x+14,y+46+i*19,l,13,400,SUB,anchor='start')
    def svg(s):
        defs=f'''<defs>
<marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="{LINE}"/></marker>
<marker id="open" viewBox="0 0 12 12" refX="11" refY="6" markerWidth="10" markerHeight="10" orient="auto-start-reverse"><path d="M1 1 L11 6 L1 11" fill="none" stroke="{LINE}" stroke-width="1.6"/></marker>
<marker id="tri" viewBox="0 0 14 14" refX="13" refY="7" markerWidth="13" markerHeight="13" orient="auto-start-reverse"><path d="M1 1 L13 7 L1 13 z" fill="#fff" stroke="{LINE}" stroke-width="1.5"/></marker>
<marker id="cplus" viewBox="0 0 16 16" refX="8" refY="8" markerWidth="14" markerHeight="14" orient="auto"><circle cx="8" cy="8" r="6.5" fill="#fff" stroke="{LINE}" stroke-width="1.4"/><path d="M8 2 V14 M2 8 H14" stroke="{LINE}" stroke-width="1.4"/></marker>
</defs>'''
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="{s.W}" height="{s.H}" viewBox="0 0 {s.W} {s.H}" font-family="Inter, sans-serif"><rect width="{s.W}" height="{s.H}" fill="#fff"/>{defs}{"".join(s.o)}</svg>'
    def render(s,out_png):
        import os
        out_png=os.path.abspath(out_png); htmlp=out_png.replace('.png','.html')
        open(htmlp,'w').write(f'<!doctype html><html><body style="margin:0">{s.svg()}</body></html>')
        import os, shutil
        chrome = os.environ.get('CHROME') or shutil.which('chromium') or shutil.which('google-chrome') \
            or '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        if not os.path.exists(chrome) and not shutil.which(chrome):
            print(f'Wrote {htmlp}. No Chrome/Chromium found: open it in a browser and screenshot, or set CHROME=/path/to/chrome.')
            return
        subprocess.run([chrome,'--headless','--no-sandbox','--hide-scrollbars','--force-device-scale-factor=2',f'--window-size={s.W},{s.H+200}',f'--screenshot={out_png}',f'file://{htmlp}'],capture_output=True)
        from PIL import Image
        im=Image.open(out_png); im.crop((0,0,s.W*2,s.H*2)).save(out_png)
