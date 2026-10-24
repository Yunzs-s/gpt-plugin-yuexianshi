import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createUpdateSource,allowedUrl,runUpdate} from '../runtime/update.mjs';

const json=relative=>JSON.parse(fs.readFileSync(new URL(relative,import.meta.url),'utf8'));

test('fork plugin, marketplace, MCP and package identities agree',()=>{
  const manifest=json('../.codex-plugin/plugin.json'),pkg=json('../package.json');
  const market=json('../../.agents/plugins/marketplace.json');
  assert.equal(manifest.name,'codex-quota-widget');assert.equal(pkg.name,manifest.name);
  assert.equal(market.name,'codex-quota-local');assert.equal(market.plugins[0].name,manifest.name);
  assert.deepEqual(Object.keys(json('../.mcp.json').mcpServers),[manifest.name]);
  assert.equal(market.plugins[0].source.path,'./gpt-niang-usage');
});

test('update source accepts only an explicit fork and rejects upstream and URLs',()=>{
  assert.equal(createUpdateSource(null),null);
  for(const repo of ['T7moris/GPT-Niang','t7moris/gpt-niang','https://github.com/me/repo','me/repo/extra','me/..','me/repo?x'])assert.throws(()=>createUpdateSource(repo));
  const source=createUpdateSource('example/quota');
  allowedUrl(source.api,{api:true,source});
  allowedUrl('https://github.com/example/quota/releases/download/v1.3.6/a.zip',{source});
  assert.throws(()=>allowedUrl('https://github.com/T7moris/GPT-Niang/releases/download/v1.3.6/a.zip',{source}));
  assert.throws(()=>allowedUrl(source.api,{api:true,source:null}));
});

test('unconfigured updates never fetch, but pending cleanup still runs',async t=>{
  const root=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),'quota-fork-test-')));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  const config={appDir:path.join(root,'program'),dataDir:path.join(root,'state'),version:'1.3.5'};
  let cleanups=0;
  const options={agentDir:path.join(root,'agent'),updateSource:null,fetchBytes:()=>assert.fail('Unconfigured updater must not fetch'),cleanup:async()=>{cleanups++;}};
  await runUpdate(config,options);
  assert.equal(jsonAt(path.join(config.dataDir,'update-status.json')).phase,'unconfigured');
  await runUpdate(config,{...options,mode:'cleanup'});assert.equal(cleanups,1);
});
const jsonAt=file=>JSON.parse(fs.readFileSync(file,'utf8'));
