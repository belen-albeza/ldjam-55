pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- general

function _init()
	poke(0x5f2d,0x3)
	screen="start"
	
	minions={}
	towers={}
	bars={}
	pickups={}
	shake=0
	t=0
	souls=0
	baddie_t=nil
	ally_t=nil
	ally_bar=nil
	baddie_bar=nil
	buy_small_btn=nil
	
	minion_spawn_ratio=60
	soul_spawn_ratio=50
	
	mouse={
		x=0,
		y=0,
		press=false,
		down=false,
		hover=false
	}
	buttons={}
	
	--init_start()
	reset_level()
end

function _draw()
	if screen=="start" then
		draw_start()
	elseif screen=="level" then
		draw_level()
	end
end

function _update()
	if screen=="start" then
		update_start()
	elseif screen=="level" then
		update_level()
	end
end

function init_start()
	spawn_tower(0,100)
	spawn_tower(112,100)
end

function update_start()
	t+=1
	update_mouse()
	foreach(buttons,update_button)
	
	if (mouse.down) then
		sfx(6)
		reset_level()
	end
end

function draw_start()
	cls()
	foreach(towers,draw_tower)
	draw_floor(80)
	
	local offset_y=0
	for i=1,15 do	pal(i,1+(t/10%15))	end
	spr(192,64-32,32+offset_y,8,1)
	pal()
	
	foreach(buttons,draw_button)
	local txt="by @ladybenko"
	print(txt,text_center(txt,64),44,7)

	txt="click to start"
	print(txt,text_center(txt,64),64,7)
	
	draw_mouse()
end

function draw_level()
	cls()
	draw_screenshake()
	
	foreach(minions,draw_minion)
	foreach(towers,draw_tower)
	foreach(pickups,draw_pickup)
	
	draw_floor(80)
	
	camera()
	draw_hud()
	foreach(bars,draw_bar)
	foreach(buttons,draw_button)
	draw_mouse()	
end

function update_level()
	t+=1

	update_mouse()
	disable_unaffordable()
	foreach(buttons,update_button)
	
	maybe_spawn_soul_pickup()
	maybe_spawn_baddie_minion()
	
	foreach(pickups,update_pickup)
	foreach(minions,update_minion)
	foreach(towers,update_tower)
	
	--collisions
	collide_mouse_vs_buttons()
	minions_vs_minions()
	mouse_vs_pickups()
end

function reset_level()
	screen="level"
	souls=2
	
	ally_t=spawn_tower(0,100)
	baddie_t=spawn_tower(112,100)
	
	ally_bar=make_bar(22,16,32,1,ally_t.life,ally_t.life,83)
	baddie_bar=make_bar(68,16,32,1,baddie_t.life,baddie_t.life,84,true)
	
	ally_bar.val=0
	baddie_bar.val=0
	buy_small_btn=make_button(60,96,17,on_small_click,"2✽")
	
	spawn_minion(128,80,-1)
	
	spawn_soul_pickup()
end

function maybe_spawn_baddie_minion()
	if t%(minion_spawn_ratio)==0 then
			minion_spawn_ratio=180+flr(rnd(30))
			spawn_minion(128,80,-1)
	end
end

function maybe_spawn_soul_pickup()
	if t%soul_spawn_ratio==0 then
		if rnd(10)<=2 then
			return spawn_big_soul_pickup()
		end
		
		return spawn_soul_pickup()
	end
end
-->8
-- minions
function spawn_minion(x,y,dir,kind)
	local m={
		x=x,
		y=y,
		offset_x=0,
		offset_y=0,
		t=0,
		dir=dir,
		life=3,
		dmg=10,
		atk=0,
		atk_ratio=30,
		versus=0,
		status="move",
		flash=0,
		kind="small"}

	m.img=spr_for_minion(m)
	m.size=size_for_minion(m)
	
	add(minions,m)
	
	return m
end

function draw_minion(m)
	local frame=(m.t/10)%2
	local img=spr_for_minion(m)+frame
	local flipx=m.dir<0
	
	-- dying fadeout
	if m.status=="die" then
		local colors={7,6,5,1}
		local idx=flr(m.t/5)+1
		local c=colors[idx]
		
		for i=1,15 do pal(i,c) end
	-- flashing white
	elseif m.flash>0 then
		for i=1,15 do pal(i,7) end
	end
	
	
	local x=m.x+m.offset_x
	local y=m.y+m.offset_y
	
	spr(img,x-4,y-8,1,1,flipx)
	pal()
end

function spr_for_minion(m)
	if m.kind=="small" and is_ally(m) then
		return 128
	elseif m.kind=="small" and is_baddie(m) then
		return 136
	end
	
	return nil
end

function size_for_minion(m)
	if m.kind=="small" then
		return 10
	end
	
	return 4
end

function update_minion(m)
	m.t+=1
	m.flash=max(0,m.flash-1)
	
	if m.status=="move" then
		update_minion_move(m)
	elseif m.status=="attack" then
		update_minion_attack(m)
	elseif m.status=="die" then
		update_minion_die(m)
	end
end

function update_minion_move(m)
		m.x+=m.dir
		
		if m.x>=124 and is_ally(m) then
			hit_tower(baddie_t,m.dmg)
			del(minions,m)
		elseif m.x<=4 and is_baddie(m)then
			hit_tower(ally_t,m.dmg)
			del(minions,m)
		end
end

function update_minion_attack(m)
		m.atk-=1
		m.offset_x=(m.atk/10)*m.dir
		if m.atk<=0 then
			m.atk=m.atk_ratio
			local did_kill=hit_minion(m.versus)
			
			if did_kill then
				m.versus=nil
				m.status="move"
			end
		end
end

function update_minion_die(m)
	m.offset_y-=0.5
	if abs(m.offset_y)>=10 then
		del(minions,m)
	end
end

function is_baddie(m)
	return m.dir<0
end

function is_ally(m)
	return m.dir>0
end

function minions_vs_minions()
	for m in all(minions) do
		if m.status!="die" then
			for other in all(minions) do
				if is_collision_minion_vs_minion(m,other) then
					attack_minion(m,other)
				end
			end
		end
	end
end

function is_collision_minion_vs_minion(m,other)
	-- avoid collision with themselves
	if m==other or other.status=="die" then
		return false
	end
	
	-- check if collision with enemies
	local are_enemies=m.dir!=other.dir
	local diff=abs(m.x-other.x)
	if diff<m.size and are_enemies then
		return true
	end
	
	return false
end

function attack_minion(m,other)
	if m.status=="attack" then
		return
	end
	
	m.status="attack"
	m.versus=other
	m.atk=rnd(m.atk_ratio/3)
end

function hit_minion(m)
	sfx(0)
	m.flash=8
	m.life-=1
	
	if m.life<=0 then
		kill_minion(m)
		return true
	end
	
	return false
end

function kill_minion(m)
	m.offset_y=0
	m.status="die"
	m.t=0
end

function hit_ally_tower(m)
	hit_tower(ally_t,5)
end

function hit_baddie_tower(m)
	hit_tower(baddie_t,5)
end

-->8
-- non-minion entities

function draw_floor(y)
	map(0,0,0,y,16,2)
end

-- pickups -----------
function spawn_pickup(x,y,kind)
	local p={
		x=x,
		y=y,
		t=0,
		kind=kind,
	}
	
	add(pickups,p)
	
	return p
end

function update_pickup(p)
	p.t+=1
	p.y-=0.2
	if p.y<-8 then
		del(pickups,p)
	end
end

function draw_pickup(p)
	local r=sin(p.t/30)*4
	local offset_y=sin(p.t/40)
	--local y=p.y+offset_y
	local y=p.y
	
	local inner_c=8
	local outer_c=7
	local inner_r=0
	if p.kind=="bigsoul" then
		inner_c=10
		outer_c=8
		inner_r=1
	end
	
	circ(p.x,y,r,outer_c)
	circfill(p.x,y,inner_r,inner_c)
end

function mouse_vs_pickups()
	for p in all(pickups) do
		if dist(mouse,p)<=4 then
			mouse.hover=true
			if mouse.press then
				pick_pickup(p)
			end
		end
	end
end

function pick_pickup(p)
	if p.kind=="soul" then
		souls+=1
		sfx(2)
	elseif p.kind=="bigsoul" then
		souls+=5
		sfx(5)
	end
	
	del(pickups,p)
end

function is_soul_pickup(p)
	return p.kind=="soul" or p.kind=="bigsoul"
end

function spawn_soul_pickup(kind)
	local x=rnd(96)+16
	local y=80
	if kind==nil then
		kind="soul"
	end
	
	return spawn_pickup(x,y,kind)
end

function spawn_big_soul_pickup()
	spawn_soul_pickup("bigsoul")
end

-- towers ------------

function draw_tower(tw)
	draw_necromancer(tw)
	
	if tw.flash>0 then
		for i=1,15 do pal(i,7) end
	end
	
	local flipx=tw.x>64
	spr(64,tw.x,48,2,4,flipx)
	pal()
end

function draw_necromancer(tw)
	local offset_y=(t%10)/5
	local x=tw.x+4
	local wzd=67
	
	if tw.x>64 then
		wzd=68
	end
	
	spr(wzd,x,48+offset_y)
end

function update_tower(t)
	t.flash=max(0,t.flash-1)
end


function spawn_tower(x,life)
	local t={
		x=x,
		life=life,
		flash=0
	}
	
	add(towers,t)
	
	return t
end

function hit_tower(t,dmg)
	t.flash=3
	t.life=max(0,t.life-dmg)
	
	sfx(1)
	screenshake(4)
	
	if is_ally_tower(t) then
		ally_bar.val=t.life
	else
		baddie_bar.val=t.life
	end
	
	if t.life<=0 then
		destroy_tower(t)
	end
end

function destroy_tower(tw)
	if is_ally_tower(tw) then
		init_gameover()
	else
		init_victory()
	end
end

function init_gameover()

end

function init_victory()

end

function is_ally_tower(tw)
	return tw.x<64
end
-->8
-- utils

function screenshake(str)
	if str==nil then
		str=6
	end
	
	shake=6
end

function draw_screenshake()
	local sx=rnd(shake)-shake/2
	local sy=rnd(shake)-shake/2
	
	shake=max(shake-0.5,0)
	if shake>10 then
		shake*=0.9
	end
	
	camera(sx,sy)
end

function point_in_rect(x,y,rx,ry,rw,rh)
	return x>=rx
		and x<rx+rw
		and y>=ry
		and y<ry+rh		  
end

function dist(a,b)
	local dx=a.x-b.x
	local dy=a.y-b.y
	
	return sqrt(dx*dx + dy*dy)
end

function text_center(txt,src_x)
	if src_x==nil then
		src_x=64
	end
	
	return src_x-(#txt*2)
end
-->8
-- ui

function draw_mouse()
	camera()
	local img=mouse.hover and 2 or 1
	spr(img,mouse.x,mouse.y)
end

function update_mouse()
	mouse.x=stat(32)
	mouse.y=stat(33)
	mouse.hover=false
	
	local old_down=mouse.down
	local old_press=mouse.press
	
	mouse.press=stat(34)==0x1
	mouse.down=mouse.press
	
	-- only fire mouse_down once
	if old_press==mouse.press and mouse.down then
		mouse.down=false
	end
end

function draw_hud()
	draw_souls()
end

function draw_souls()
	local txt="✽"..souls
	print(txt,text_center(txt,64),4,7)
end

function draw_button(b)
	if b.flash>0 then
		for i=1,15 do pal(i,7) end
	end
	
	if b.disabled then
		for i=1,15 do pal(i,5) end
	end
	
	spr(b.icon,b.x,b.y)

	
	if b.hover and b.flash==0 then
		spr(16,b.x,b.y)
	end
	
	pal()
	
	if b.label!=nil then
		local x=text_center(b.label,b.x+3)
		print(b.label,x,b.y+10)
	end
end

function update_button(b)
	b.flash=max(0,b.flash-1)
end

function collide_mouse_vs_buttons()
	for b in all(buttons) do
		if not b.disabled and point_in_rect(mouse.x,mouse.y,b.x,b.y,b.size,b.size) then
			b.hover=true
			if mouse.down then
				b.flash=3
				b.fn()
			end
		else
			b.hover=false
		end
	end
end

function make_button(x,y,icon,fn,label)
	local b={
		x=x,
		y=y,
		icon=icon,
		size=8,
		flash=0,
		fn=fn,
		label=label,
		disabled=false
	}
	
	add(buttons,b)
	
	return b
end

function on_small_click()
	try_buy_minion("small")
end

function make_bar(x,y,w,h,val,max_val,icon,flipx)
	local b={
		x=x,
		y=y,
		w=w,
		h=h,
		val=val,
		max_val=max_val,
		icon=icon,
		flipx=flipx
	}
	
	add(bars,b)
	
	return b
end

function draw_bar(b)
	local w=ceil(b.w*(b.val/b.max_val))
	
	if b.icon and not b.flipx then
		spr(b.icon,b.x,b.y-4)
	elseif b.icon then
		spr(b.icon,b.x+b.w,b.y-4)
	end
	
	local x0=b.x+8
	if b.flipx then
		x0=b.x
	end
	
	rectfill(x0,b.y,x0+b.w-1,b.y+b.h-1,1)
	
	if b.flipx then
		x0=b.x+(b.w-w)
	end
	
	
	local x1=x0+w-1
	
	if w>0 then
		rectfill(x0,b.y,x1,b.y+b.h-1,7)
	end
end
-->8
-- game logic
function try_buy_minion(kind)
	local price=price_for_minion(kind)
	
	if souls>=price then
		souls-=price
		buy_minion(kind)	
	end
end

function buy_minion(k)
	sfx(4)
	spawn_minion(0,80,1,k)
end

function price_for_minion(k)
	if k=="small" then
		return 2
	end
	
	return 1
end

function disable_unaffordable()
	buy_small_btn.disabled=
		souls<price_for_minion("small")
end
__gfx__
00000000777100007881000000000000000000000000000000000000000000001111111111111111000000000000000000000000000000000000000000000000
00000000771000008810000000000000000000000000000000000000000000000101010001010100000000000000000000000000000000000000000000000000
00700700717100008181000000000000000000000000000000000000000000001001000101010000000000000000000000000000000000000000000000000000
00077000101500001015000000000000000000000000000000000000000000000000000100010000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000001000000001000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000010000100000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cccccc0067766600000000000000000000000000000000000000000000000000000000000000000006666000000000000000000000000000000000000000000
c000000c600000060000000000000000000000000000000000000000000000000056650000677600067777600000000000000000000000000000000000000000
c000000c708008060000000000000000000000000000000000000000000000000560065006700760670000760000000000000000000000000000000000000000
c000000c708888060000000000000000000000000000000000000000000000000606606007077070670770760000000000000000000000000000000000000000
c000000c608181050000000000000000000000000000000000000000000000000606606007077070670770760000000000000000000000000000000000000000
c000000c608888050000000000000000000000000000000000000000000000000560065006700760670000760000000000000000000000000000000000000000
c000000c600000050000000000000000000000000000000000000000000000000056650000677600067777600000000000000000000000000000000000000000
0cccccc0066655500000000000000000000000000000000000000000000000000000000000000000006666000000000000000000000000000000000000000000
06776660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70882006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70888206000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60888205000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60882005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06665550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000022220805550800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000002222222887728800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000002222112577776500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000022228518507076500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c000000c00000000022255511577776500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cd00000c00000dc10000000022222222057575100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cd1000dcd0001dc10000000002221110011111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cdd100dcd001ddc10000000001111110011111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cddd0ddcdd0dddc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cddd5ddcdd5dddc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cddddddcddddddc10000000000022200080000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cd1111dcd111dd110000000000221120027778200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1115511c11551d100000000002285180000707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51555511155551000000000002222220007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555d55155d551000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d5ddddd5dddd51000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dddd0dddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dd000ddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dd000ddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dd000dddd100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55dd555ddd1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd16000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd10000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd14444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008008000000000000000000000000000000000000000000000000000000000000c00c00000000000000000000000000000000000000000000000000
008008000088880000000000000000000000000000000000000000000000000000c00c0000cccc00000000000000000000000000000000000000000000000000
008888000081810000000000000000000000000000000000000000000000000000cccc0000c1c100000000000000000000000000000000000000000000000000
008181000088880000000000000000000000000000000000000000000000000000c1c10000cccc00000000000000000000000000000000000000000000000000
008888000002200000000000000000000000000000000000000000000000000000cccc0000011000000000000000000000000000000000000000000000000000
00200200000220000000000000000000000000000000000000000000000000000010010000011000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777000000000000000000000000000000000000000000000000000077700000000000000000000000000000000000000000000000000000000000000000000
77757700000000000000000000000000000000000000000000000000770070000000000000000000000000000000000000000000000000000000000000000000
07750070777700077000777500007500007777007500750000077700770500000000000000000000000000000000000000000000000000000000000000000000
07750070075000700700070750007500000750007500750000750570777700000000000000000000000000000000000000000000000000000000000000000000
07750070075000777700077775007500000750007500750000707070005770000000000000000000000000000000000000000000000000000000000000000000
07750070075000700700070075007700700750007707770070750570050770000000000000000000000000000000000000000000000000000000000000000000
77777750777707500570777775077777007777077775777700077700777700000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70077077700700777077700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70070007007070707007000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70007007007770770007000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70077007007070707007000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0808080908090808080809090908080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000015330183301d330223202631029300273001c30003000010002b0002c0002700020000180000f0000b0000b0000000000000000000000000000000000000000000000000000000000000000000000000
00060000101500d1500b15008150031300111001150072000220000200013000060025600276002a6002b6002e6002f6003260000000000000000000000000000000000000000000000000000000000000000000
000400003b7502d750297502b7402f740397303972003710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000500000c04007000020000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000022750257402a7303271000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
0006000023550295502d550345502a5502c5502755030540375303f51033500355003850000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000800001605018050180501b0501e0501f05024050270502b0502f050360502f05028050200501d040130400d0301b040250400b0200001033000370003d0003e0003f0003f0003f00000000000000000000000
