"use strict";
const $ = id => document.getElementById(id);
let snapshot = null, online = false, timer = null, loading = false;
const labels = {pending:"待领取", claimed:"进行中", completed:"已完成", cancelled:"已取消", failed:"失败"};
const element = (tag, cls, text) => { const e = document.createElement(tag); if(cls)e.className=cls; if(text!==undefined)e.textContent=text; return e; };
const dateLabel = text => { const d = new Date(text); return Number.isNaN(d.valueOf()) ? "未知" : d.toLocaleString("zh-CN",{hour12:false}); };
function remaining(task) { if(!task.lease_until)return null; const time=Date.parse(task.lease_until); return Number.isFinite(time)?Math.floor((time-Date.now())/1000):null; }
function needsAttention(t) { const seconds=remaining(t); return t.state==="failed" || !!t.meta.blocker || (t.state==="claimed" && (seconds===null || seconds<60)); }
function render(){
 if(!snapshot)return;
 const tasks=snapshot.tasks, agents=snapshot.agents;
 for(const state of ["pending","claimed","completed"])$(state).textContent=tasks.filter(t=>t.state===state).length;
 $("attention").textContent=tasks.filter(needsAttention).length;
 const query=$("search").value.trim().toLowerCase(), filter=$("state").value;
 const visible=tasks.filter(t=>(filter==="all" || (filter==="attention"?needsAttention(t):t.state===filter)) && JSON.stringify(t).toLowerCase().includes(query));
 $("count").textContent=`${visible.length} / ${tasks.length}`;
 $("window-note").textContent=snapshot.truncated?"已截取最近 200 条，旧任务可能不在此窗口中。":"最近任务窗口（最多 200 条），统计不代表独立验收。";
 const expanded=new Set([...document.querySelectorAll("details[open]")].map(e=>e.dataset.id));
 $("task-list").replaceChildren();
 if(!visible.length)$("task-list").append(element("div","empty",tasks.length?"没有匹配的任务，试试清空筛选。":"coord 已连接，尚无任务。"));
 for(const t of visible){
  const row=element("article","task"), top=element("div","task-top");
  top.append(element("span",`badge ${Object.hasOwn(labels,t.state)?t.state:""}`,labels[t.state]||t.state||"未知"),element("span","task-title",t.name||"未命名任务"));
  if(t.priority==="high"||t.priority==="urgent")top.append(element("span","alert",t.priority==="urgent"?"紧急":"高优先级"));
  row.append(top);
  const info=element("div","task-info");
  info.append(element("span","",`${t.meta.tool||"客户端未声明"} · ${t.meta.model||"模型未声明"}`),element("span","",`会话 ${t.claimed_by||"未领取"}`));
  const seconds=remaining(t);
  if(t.state==="claimed")info.append(element("span",needsAttention(t)?"alert":"",seconds===null?"租约未知":seconds<0?"租约已过期，等待 coord 回收":`租约剩余 ${Math.floor(seconds/60)}分${seconds%60}秒`));
  if(t.meta.scope.length)info.append(element("span","scope",t.meta.scope.join(" · ")));
  row.append(info);
  if(t.meta.blocker)row.append(element("p","alert",`阻塞声明：${t.meta.blocker}`));
  const detail=element("details");detail.dataset.id=t.id;detail.open=expanded.has(t.id);detail.append(element("summary","","交接与任务详情"));
  const grid=element("div","detail-grid");
  for(const [key,value] of [["任务 ID",t.id],["角色",t.meta.role],["项目",t.meta.project],["交接路径",t.meta.handoff],["最后变更",dateLabel(t.updated_at)],["状态含义",t.state==="completed"?"coord 账本完成；独立复核请查报告":"状态来自 coord，未由面板独立验证"]])grid.append(element("b","",key),element("span","",value||"未声明"));
  detail.append(grid);row.append(detail);$("task-list").append(row);
 }
 $("agent-count").textContent=agents.length;$("agent-list").replaceChildren();
 if(!agents.length)$("agent-list").append(element("div","empty","coord 已连接，尚无会话心跳。"));
 for(const a of agents){ const card=element("article",`agent ${a.presence}`);card.append(element("strong","",a.name||a.id),element("span","presence",a.presence==="recent"?"● 近期活跃":a.presence==="stale"?"◌ 心跳过久":"◌ 心跳时间未知"),element("p","",a.id),element("p","",`最后心跳 ${dateLabel(a.last_seen)}`),element("p","",`任务 ${a.current_task||"未声明"}`));$("agent-list").append(card); }
 $("updated").textContent=`${online?"最后成功刷新":"保留的过期快照"}：${dateLabel(snapshot.observed_at)}`;
}
async function refresh(){
 if(loading)return;loading=true;$("refresh").disabled=true;clearTimeout(timer);
 const controller=new AbortController(), timeout=setTimeout(()=>controller.abort(),9000);
 try{
  const response=await fetch("/api/snapshot",{signal:controller.signal,cache:"no-store"});const data=await response.json();
  $("source").textContent=`${data.mode==="demo"?"演示来源":"coord"}：${data.source}`;
  $("mode").textContent=data.mode==="demo"?"DEMO / 演示数据":"LOCAL / 本地实时";
  if(!response.ok||!data.connected)throw new Error(data.error||"连接不可用");
  snapshot=data;online=true;document.body.classList.remove("stale-data");
  $("connection").className=`connection ${data.mode==="demo"?"demo":""}`;
  $("connection").textContent=data.mode==="demo"?"演示模式 · 以下是合成任务，未连接真实 coord；请用不带 --demo 的命令查看实际协作。":"● coord 已连接 · 列表自动更新；无需反复打开终端。";
  render();
 }catch(error){
  online=false;document.body.classList.add("stale-data");$("connection").className="connection error";
  $("connection").textContent=`连接不可用 · ${error.name==="AbortError"?"请求超时":error.message} ${snapshot?"下方保留上次快照，已过期。":"尚无快照，不能判断当前任务状态。"}`;
  if(snapshot)render();else{$("task-list").replaceChildren(element("div","empty","coord 尚未连接，启动服务后会自动重试。"));$("agent-list").replaceChildren(element("div","empty","会话状态未知"));}
 }finally{clearTimeout(timeout);loading=false;$("refresh").disabled=false;if($("auto").checked)timer=setTimeout(refresh,5000);}
}
$("search").addEventListener("input",render);$("state").addEventListener("change",render);$("refresh").addEventListener("click",refresh);
$("auto").addEventListener("change",()=>{clearTimeout(timer);if($("auto").checked)refresh();});
refresh();
