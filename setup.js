// Prepara o projeto Android do jogo (rode: node setup.js). Com --build também gera o APK.
const fs = require('fs'), path = require('path'), https = require('https'), cp = require('child_process');
const ROOT = __dirname, WWW = path.join(ROOT,'www'), isWin = process.platform==='win32';
const run = (cmd, cwd) => { console.log('> '+cmd); cp.execSync(cmd, {cwd:cwd||ROOT, stdio:'inherit'}); };
const get = (url, dest) => new Promise((ok,no) => https.get(url, r => {
  if(r.statusCode>=300 && r.statusCode<400 && r.headers.location) return get(r.headers.location,dest).then(ok,no);
  if(r.statusCode!==200) return no(new Error('HTTP '+r.statusCode));
  const f = fs.createWriteStream(dest); r.pipe(f); f.on('finish', () => f.close(ok));
}).on('error',no));
const edit = (file, fn) => { const s = fs.readFileSync(file,'utf8'), t = fn(s); if(t!==s) fs.writeFileSync(file,t); return t!==s; };

(async () => {
  fs.mkdirSync(WWW,{recursive:true});
  if(fs.existsSync(path.join(ROOT,'index.html'))) fs.copyFileSync(path.join(ROOT,'index.html'), path.join(WWW,'index.html'));   // index.html na raiz → www/
  const three = path.join(WWW,'three.min.js');
  if(!fs.existsSync(three) || fs.statSync(three).size<100000){
    console.log('Baixando three.min.js (r128)…');
    await get('https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js', three);
  }
  if(!fs.existsSync(path.join(ROOT,'node_modules'))) run('npm install');
  if(!fs.existsSync(path.join(ROOT,'android'))) run('npx cap add android');

  const A = path.join(ROOT,'android','app','src','main');
  // 1) paisagem + sem recriar a tela ao girar
  edit(path.join(A,'AndroidManifest.xml'), s => s.includes('sensorLandscape') ? s : s.replace('<activity', '<activity\n            android:screenOrientation="sensorLandscape"'));
  // 2) tela cheia imersiva, tela sempre ligada e área do notch
  const javaDir = path.join(A,'java'); let mainJava = null;
  (function walk(d){ fs.readdirSync(d,{withFileTypes:true}).forEach(e => { const p = path.join(d,e.name); if(e.isDirectory()) walk(p); else if(e.name==='MainActivity.java') mainJava = p; }); })(javaDir);
  if(mainJava){
    const pkg = /package\s+([\w.]+);/.exec(fs.readFileSync(mainJava,'utf8'))[1];
    fs.writeFileSync(mainJava, `package ${pkg};

import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        immersive();
    }
    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) immersive();
    }
    private void immersive() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }
}
`);
  }
  edit(path.join(A,'res','values','styles.xml'), s => s.includes('windowFullscreen') ? s : s.replace(/(<style name="AppTheme\.NoActionBar"[^>]*>)/, '$1\n        <item name="android:windowFullscreen">true</item>'));

  run('npx cap sync android');
  if(process.argv.includes('--build')){
    run((isWin ? 'gradlew.bat' : './gradlew')+' assembleDebug', path.join(ROOT,'android'));
    console.log('\nAPK pronto em: android/app/build/outputs/apk/debug/app-debug.apk');
  } else {
    console.log('\nPronto! Agora: npx cap open android  (e Build > Build APK) — ou rode: node setup.js --build');
  }
})().catch(e => { console.error('\nERRO:', e.message); process.exit(1); });
