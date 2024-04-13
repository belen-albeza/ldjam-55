pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
minions={}
t=0

function _init()
	reset_game()
end

function _draw()
	cls()
	
	foreach(minions,draw_minion)
	
	draw_floor(80)
end

function _update()
	t+=1
	
	foreach(minions,update_minion)
	
	--collisions
	minions_vs_minions()
end

function reset_game()
	minions={}
	t=0
	
	spawn_minion(8,80,1)
	spawn_minion(120,80,-1)
end
-->8
-- minions
function spawn_minion(x,y,dir)
	local m={
		x=x,
		y=y,
		t=0,
		dir=dir,
		status="move",
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
	spr(img,m.x-4,m.y-8,1,1,flipx)
end

function spr_for_minion(m)
	if m.kind=="small" then
		return 1
	end
	
	return nil
end

function size_for_minion(m)
	if m.kind=="small" then
		return 2
	end
	
	return 4
end

function update_minion(m)
	m.t+=1
	
	if m.status=="move" then
		m.x+=m.dir
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
		for other in all(minions) do
			if is_collision_minion_vs_minion(m,other) then
				attack_minion(m,other)
			end
		end
	end
end

function is_collision_minion_vs_minion(m,other)
	-- avoid collision with themselves
	if m==other then
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
	m.status="attack"
	hit_minion(other)
end

function hit_minion(m)
	del(minions,m)
end
-->8
-- hud and attrezo

function draw_floor(y)
	map(0,0,0,y,16,2)
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000001111111111111111000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000101010001010100000000000000000000000000000000000000000000000000
00700700000000000080080000000000000000000000000000000000000000001001000101010000000000000000000000000000000000000000000000000000
00077000008008000088880000000000000000000000000000000000000000000000000100010000000000000000000000000000000000000000000000000000
00077000008888000081810000000000000000000000000000000000000000000001000000001000000000000000000000000000000000000000000000000000
00700700008181000088880000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000
00000000008888000002200000000000000000000000000000000000000000000000010000100000000000000000000000000000000000000000000000000000
00000000002002000002200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0808080908090808080809090908080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
