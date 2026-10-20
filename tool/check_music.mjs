// Real-browser smoke test of gesture unlock, audible PCM, pause and mute.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve('build/web');
const types={'.js':'text/javascript','.html':'text/html','.wasm':'application/wasm','.json':'application/json'};
const server=http.createServer((req,res)=>{
 const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]==='/'?'/index.html':req.url.split('?')[0]));
 if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return}
 res.setHeader('Content-Type',types[path.extname(file)]??'application/octet-stream');fs.createReadStream(file).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser;
try{
 browser=await chromium.launch({args:['--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:720}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.text().includes('[music]'))console.log(m.text())});
 await page.addInitScript(()=>{
  window.audioProbes=[];
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(destination,...args){
   const result=connect.call(this,destination,...args);
   if(destination instanceof AudioDestinationNode){
    const analyser=this.context.createAnalyser();analyser.fftSize=2048;
    connect.call(this,analyser);window.audioProbes.push(analyser);
   }
   return result;
  };
 });
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 await page.waitForFunction(()=>globalThis.rogueAgent?.ready(),null,{timeout:60000});
 const state=()=>page.evaluate(()=>rogueAgent.state());
 assert.equal((await state()).music.started,false,'No autoplay before a gesture');
 await page.mouse.click(640,360);
 await page.keyboard.press('d');
 await page.waitForFunction(()=>rogueAgent.state().music.started||rogueAgent.state().music.error,null,{timeout:30000});
 assert.equal((await state()).music.error,null);
 await page.waitForFunction(()=>audioProbes.some(a=>{const data=new Float32Array(2048);a.getFloatTimeDomainData(data);return data.some(x=>Math.abs(x)>0.005)}),null,{timeout:15000});
 console.log('PASS gesture unlock and audible synth output');
 await page.waitForTimeout(3500);
 const playing=await state();assert(playing.music.bufferedBytes>0&&playing.music.bufferedBytes<90000);
 assert(playing.music.targetBpm>118,'Enemy pressure reaches the score');
 console.log('PASS bounded stream and live enemy pressure',playing.music);
 await page.evaluate(()=>rogueAgent.setPaused(true));
 const beforePause=(await state()).music;
 await page.waitForTimeout(600);
 const afterPause=(await state()).music;
 assert.equal(afterPause.suspended,true);assert.equal(afterPause.renderedSeconds,beforePause.renderedSeconds);
 await page.evaluate(()=>rogueAgent.setPaused(false));
 await page.keyboard.press('m');
 assert.equal((await state()).music.enabled,false);
 const muted=(await state()).music.renderedSeconds;
 await page.waitForTimeout(600);assert.equal((await state()).music.renderedSeconds,muted);
 await page.keyboard.press('m');
 await page.waitForTimeout(600);assert.equal((await state()).music.enabled,true);
 assert((await state()).music.renderedSeconds>muted);
 console.log('PASS pause/resume and M mute/unmute');
 assert.deepEqual(errors,[]);
 console.log('PASS no browser errors');
}finally{await browser?.close();await new Promise(r=>server.close(r))}
