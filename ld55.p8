pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- general

function _init()
	poke(0x5f2d,0x3)
	
	minions={}
	towers={}
	shake=0
	t=0
	souls=10
	
	mouse_x=0
	mouse_y=0
	mouse_press=false
	mouse_down=false
	buttons={}
	
	reset_game()
end

function _draw()
	cls()
	draw_screenshake()
	
	foreach(minions,draw_minion)
	foreach(towers,draw_tower)
	
	draw_floor(80)
	
	draw_hud()
	foreach(buttons,draw_button)
	draw_mouse()
end

function _update()
	update_mouse()
	foreach(buttons,update_button)
	
	t+=1
	
	foreach(minions,update_minion)
	foreach(towers,update_tower)
	
	--collisions
	collide_mouse_vs_buttons()
	minions_vs_minions()
end

function reset_game()
	spawn_tower(0)
	spawn_tower(112)
	
	make_button(2,96,17,on_small_click,"2")
	
	spawn_minion(0,80,1)
	spawn_minion(128,80,-1)
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
			hit_baddie_tower(m)
			del(minions,m)
		elseif m.x<=4 and is_baddie(m)then
			hit_ally_tower(m)
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
	hit_tower(towers[1],1)
end

function hit_baddie_tower(m)
	hit_tower(towers[2],1)
end

-->8
-- attrezo

function draw_floor(y)
	map(0,0,0,y,16,2)
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


function spawn_tower(x)
	local t={
		x=x,
		life=1,
		flash=0
	}
	
	add(towers,t)
	
	return t
end

function hit_tower(t,dmg)
	t.flash=3
	t.life-=1
	sfx(1)
	
	screenshake(4)
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
-->8
-- ui

function draw_mouse()
	camera()
	spr(1,mouse_x,mouse_y)
end

function update_mouse()
	mouse_x=stat(32)
	mouse_y=stat(33)
	
	local old_down=mouse_down
	local old_press=mouse_press
	
	mouse_press=stat(34)==0x1
	mouse_down=mouse_press
	
	-- only fire mouse_down once
	if old_press==mouse_press and mouse_down then
		mouse_down=false
	end
end

function draw_hud()
	draw_souls()
end

function draw_souls()
	spr(3,2,2)
	print(souls,12,4,7)
end

function draw_button(b)
	if b.flash>0 then
		for i=1,15 do pal(i,7) end
	end
	
	spr(b.icon,b.x,b.y)

	
	if b.hover and b.flash==0 then
		spr(16,b.x,b.y)
	end
	
	pal()
	
	if b.label!=nil then
		print(b.label,b.x+2,b.y+10)
	end
end

function update_button(b)
	b.flash=max(0,b.flash-1)
end

function collide_mouse_vs_buttons()
	for b in all(buttons) do
		if point_in_rect(mouse_x,mouse_y,b.x,b.y,b.size,b.size) then
			b.hover=true
			if mouse_down then
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
		label=label
	}
	
	add(buttons,b)
	
	return b
end

function on_small_click()
	try_buy_minion("small")
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
	spawn_minion(0,80,1,k)
end

function price_for_minion(k)
	if k=="small" then
		return 2
	end
	
	return 1
end
__gfx__
00000000777100000000000000677700000000000000000000000000000000001111111111111111000000000000000000000000000000000000000000000000
00000000771000000000000005000070000000000000000000000000000000000101010001010100000000000000000000000000000000000000000000000000
00700700717100000000000050000007000000000000000000000000000000001001000101010000000000000000000000000000000000000000000000000000
00077000101500000000000000050077000000000000000000000000000000000000000100010000000000000000000000000000000000000000000000000000
00077000000000000000000000660077000000000000000000000000000000000001000000001000000000000000000000000000000000000000000000000000
00700700000000000000000006766777000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000
00000000000000000000000007777770000000000000000000000000000000000000010000100000000000000000000000000000000000000000000000000000
00000000000000000000000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cccccc0067766600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c600000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c708008060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c708888060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c608181050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c608888050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c000000c600000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cccccc0066655500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
cddddddcddddddc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cd1111dcd111dd110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1115511c11551d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51555511155551000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
__map__
0808080908090808080809090908080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000015330183301d330223202631029300273001c30003000010002b0002c0002700020000180000f0000b0000b0000000000000000000000000000000000000000000000000000000000000000000000000
00060000101500d1500b15008150031300111001150072000220000200013000060025600276002a6002b6002e6002f6003260000000000000000000000000000000000000000000000000000000000000000000
