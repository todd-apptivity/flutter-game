// Validate PNG pixels in Chromium and capture the local asset preview.
import { chromium } from 'playwright';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const manifest=JSON.parse(await readFile('artwork/prompts.json','utf8'));
const browser=await chromium.launch({headless:true});
try {
 const page=await browser.newPage({viewport:{width:1060,height:1100},deviceScaleFactor:1});
 await page.goto(pathToFileURL(resolve('artwork/preview.html')).href);
 await page.evaluate(()=>window.assetsReady);
 const report=[];
 for(const {name,size,frames} of manifest){
  const data='data:image/png;base64,'+(await readFile(`assets/images/${name}.png`)).toString('base64');
  const result=await page.evaluate(async({data,name,size,frames})=>{
   const img=new Image();img.src=data;await img.decode();
   const c=document.createElement('canvas');c.width=img.width;c.height=img.height;const ctx=c.getContext('2d');ctx.drawImage(img,0,0);const pixels=ctx.getImageData(0,0,c.width,c.height).data;
   const stats=Array.from({length:frames},(_,frame)=>{let transparent=0,visible=0,red=0;for(let y=0;y<size;y++)for(let x=0;x<size;x++){const i=(y*c.width+frame*size+x)*4;if(pixels[i+3]===0)transparent++;else visible++;if(pixels[i+3]>128&&pixels[i]>80&&pixels[i]>pixels[i+1]*1.7)red++}return {transparent,visible,red}});
   return {name,width:img.width,height:img.height,expected:[size*frames,size],frames:stats};
  },{data,name,size,frames});
  if(result.width!==size*frames||result.height!==size||result.frames.some(f=>!f.transparent||!f.visible))throw Error('Invalid asset '+name);
  report.push(result);
 }
 await writeFile('artwork/validation.json',JSON.stringify(report,null,2)+'\n');
 await page.screenshot({path:'artwork/preview.png',fullPage:true});
 console.log(JSON.stringify(report,null,2));
} finally {await browser.close()}
