local g = golly()

local smallobj = {}
local glider = g.parse("2o$obo$o!")
local start_shift=32
local max_total_cost = 70 -- initial value
local total_cost_range = 6 -- bounds max_total_ost to best_cost_found + total_cost_range

local min_splitter_cost, min_turner_cost -- for curent combination strategy to limit the scan/load of the other cathegory
local data_infile_dir = "c:\\golly\\Patterns\\RawSplitters\\" -- contain files 0_turners.txt, 90_turners.txt, 180_turners.txt, 2_splitters_parallel.txt, 2_splitters_opposte.txt, and 2_splitters_perp.txt
-- the files have two columns columns semicolon delimted, where first column contains estimated splitter build cost (distances are not considered and currently pslmake small objet costs are used,
-- but any distance ignorring costs would work well (toad is pair of blinkers, long barges are cmbinations of tubes with bares ...)
-- each file should be sorted by cost, otherwise optimisation could miss some splitter/turner behind a costy one (causing a search cut)
-- the other column contains rle of the spltter/turner with a oo$obo$o activation glider as a east-south most object.
-- 0 turners should start by 0 cost "2o$obo$o!" rle row (to allow location of splitters not requiring a turner correction.

local data_outfile_dir = "c:\\golly\\Patterns\\Workdir\\"
-- Program is started from golly having only two parallel gliders in the starting life pattern. The cheapest combined splitters from the collection should be returned and saved in the data_outfile_dir

local dirs = { { "0", 1, 1 }, { "90", -1, 1 }, { "180", -1, -1 }, { "270", 1, -1 } }
local rel_dirs = {{"parallel",1}, {"opposite",3}, {"perp",2}}
local dirsignx, dirsigny
local todebug = false

g.autoupdate(false)
g.setalgo('HashLife')
g.setrule("Life")
g.setoption("savexrle", 0)

local function inttostring(num)
    num=math.floor(num+0.5)
    return string.sub(num, 1, string.find(num .. ".", "%.") - 1)
end

local outputs = {}

local tgt_lanedist,tgt_delays,tgt_delay
-- I am skipping test the parallel splitters contain the required
-- let us start with perp splitters corrected by a 90turner
local turners -- turners90 addressed by 2delay+colorchange, contains list of turners each {cost,scx,scy,p,rle} (period p is at most 2) central glieder cordinate in phase 0 ... expecting std oo$obo$o glider input
-- turners 0 addressed by delay times line_change (delay.."x"..line_change key) the same fields
-- turners 180 adressed by line_change * 8 + delay % 8 the same fields

local function get_rle()
    local foofile=data_outfile_dir .. "foo.rle"
    g.store(g.getcells(g.getrect()),foofile)
    g.update()
    local r=io.open(foofile,"r")
    r:read()
    local rle=""
    local rleadd=r:read()
    while rleadd do
        rle=rle..rleadd
        rleadd=r:read()
    end
    r:close()
    return rle
end

local function locate_start_glider(rlestr) -- oo$obo$o
    local patt=g.parse(rlestr)
    local maxxpy,x,y=-99999,-99999,-99999
    local step = 2+(#patt%2)
    for i=1,#patt-1,step do
        local xpy=patt[i+1]+patt[i]
        if maxxpy<xpy then
            x,y,maxxpy = patt[i],patt[i+1],xpy
        end
    end
    return x-2,y-1
end

local function locate_start_glider_center(rlestr) -- oo$obo$o
    local xleft,ytop = locate_start_glider(rlestr)
    return xleft+1,ytop+1
end

local function remove_glider_phase(rlestr,x,y,p) -- oo$obo$o
    g.new("turner_prepare")
    g.setrule("Life")
    g.putcells(g.parse(rlestr), -x, -y, 1, 0, 0, 1);
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor");
    g.setstep(0)
    if (p~=0) then
        g.step()
    end
    --g.note("test me, the glider should be removed")
    return g.getcells(g.getrect())
end

local function hash_turners(cost, rlestr)
    --dirsignx, dirsigny was set and heps in processing
    if cost + min_splitter_cost > max_total_cost then -- we reached portion of the file which cannot be usefull
        g.show(cost.." turners ... we reached portion of the file which cannot be usefull")
        return true
    end
    g.new("classify_turner")
    g.setrule("Life")
    g.setbase(2)
    local startx,starty=locate_start_glider_center(rlestr)
    local patt = g.parse(rlestr, -startx, -starty)  -- storing pattern centralised in glider center (be carefull when used n horizontal rather to vertical direction,
                                                    --the phase changes to 2 so center relatve to phase 0 shifts
    g.putcells(patt)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    --g.note("positioned!")
    g.setstep(0)
    g.step()
    g.putcells(patt, 0, 0, 1, 0, 0, 1, "xor")
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    local period = (0 + g.getpop() == 0) and 1 or 2
    g.new("classify_turner")
    g.setbase(2)
    g.putcells(patt)
    g.setstep(10)
    g.step()
    g.setstep(6)
    local rect0 = g.getrect()
    local pop0 = 0 + g.getpop()
    if pop0 % 5 ~= 0 or pop0 == 0 then
        g.note("A1 "..pop0.." "..rlestr)
        return
    end
    local patt0 = g.getcells(rect0)
    g.step()
    local rect1 = g.getrect()
    if not rect1 then
        g.note("B1")
        return
    end
    local pop1 = 0 + g.getpop()
    if pop1 ~= pop0 then
        g.note("C1")
        return
    end
    local gliderCnt = pop0 / 5
    if gliderCnt ~= 1 then
        g.note("bad gldercount for turner")
        return
    end
    local patt1 = g.getcells(rect1)
    while rect0[3] ~= 3 or rect0[4] ~= 3 do
        g.step()
        g.update()
        rect1, rect0 = g.getrect(), rect1
        if not rect1 then
            g.note("D1")
            return
        end
        pop1 = 0 + g.getpop()
        if pop1 ~= pop0 then
            g.note("E1")
            return
        end
        patt1, patt0 = g.getcells(rect1), patt1
        g.putcells(patt0, 0, 0, 1, 0, 0, 1, "or")
        g.putcells(patt0, 0, 0, 1, 0, 0, 1, "xor")
        local pop2 = 0 + g.getpop()
        if pop2 ~= pop1 then
            g.note("F1")
            return
        end
    end
    if ((rect0[2] - rect1[2]) * dirsigny < 0) or ((rect0[1] - rect1[1]) * dirsignx < 0) then
        g.note("G bad dirsigns for turner")
        return
    end
    local phase, gen, x0, y0 = -1, 0 + g.getgen() --
    if g.getcell(rect1[1] + 1 + dirsignx, rect1[2] + 1) == 1 then
        phase = 0
        x0, y0 = rect1[1] + dirsignx * (gen // 4), rect1[2] + dirsigny * (gen // 4)
    elseif g.getcell(rect1[1] + 1 - dirsignx, rect1[2] + 1 + dirsigny) == 1 then
        phase = 3
        x0, y0 = rect1[1] + dirsignx * (1 + (gen // 4)), rect1[2] + dirsigny * (1 + (gen // 4))
    end
    if g.getcell(rect1[1] + 1, rect1[2] + 1 + dirsigny) == 1 then
        phase = 2
        x0, y0 = rect1[1] + dirsignx * (1 + (gen // 4)), rect1[2] + dirsigny * (gen // 4)
    elseif g.getcell(rect1[1] + 1 + dirsignx, rect1[2] + 1 - dirsigny) == 1 then
        phase = 1
        x0, y0 = rect1[1] + dirsignx * (1 + (gen // 4)), rect1[2] + dirsigny * (gen // 4)
    end
    x0,y0 = x0+1,y0+1 --centers rather to top left
    local xpyshift, ymxshift = x0 + y0, y0 - x0 -- center rather to topleft
    local critery1,critery2,hash
    if dirsignx+dirsigny==2 then --0 turn
        critery1,critery2 = inttostring(ymxshift),inttostring(2*xpyshift-phase)
        --critery1txt,critery2txt="lineshift=","delay="
        hash = critery1.."x"..critery2
    elseif dirsignx+dirsigny==-2 then --180 turn
        critery1,critery2 = ymxshift,(-2*(x0+y0)-phase) % 8
        --critery1txt,critery2txt="lineshift=","ph%8="
        hash = 8*critery1+critery2
    else
        critery1,critery2 = (ymxshift%2),4*y0-phase
        hash = 2*critery2+critery1
    end
    if not turners[hash] then
        turners[hash] = {}
    end
    turners[hash][1+#turners[hash]] = {cost,x0,y0,phase,period,rlestr} --center position relative to center position of the staring glider
end

local function classify_2splitter_dirs(rlestr)
    dirsignx, dirsigny = 2,2 -- to be set 2,2 signals bad pattern
    g.new("classify_2splitter_dirs")
    g.setrule("Life")
    g.setbase(2)
    g.putcells(g.parse(rlestr))
    g.setstep(10)
    g.step()
    g.setstep(6)
    local rect0 = g.getrect()
    local pop0 = 0 + g.getpop()
    if pop0 % 5 ~= 0 or pop0 == 0 then
        g.show("pop0 "..pop0)
        return
    end
    local patt0 = g.getcells(rect0)
    g.step()
    local rect1 = g.getrect()
    if not rect1 then
        g.show("empty")
        return
    end
    local pop1 = 0 + g.getpop()
    if pop1 ~= pop0 then
        g.show("pop0,pop1 "..pop0..","..pop1)
        return
    end
    local gliderCnt = pop0 / 5
    if gliderCnt ~= 2 then
        g.show("glider count "..gliderCnt)
        return
    end
    local patt1 = g.getcells(rect1)
    while (rect1[1] - rect0[1]) % 16 ~= 0 or (rect1[2] - rect0[2]) % 16 ~= 0 or (rect1[3] - rect0[3]) % 16 ~= 0 or (rect1[4] - rect0[4]) % 16 ~= 0 or rect1[1] - rect0[1] == 0 or rect1[2] - rect0[2] == 0 do
        g.step()
        g.update()
        rect1, rect0 = g.getrect(), rect1
        if not rect1 then
            g.show("empty 2")
            return
        end
        pop1 = 0 + g.getpop()
        if pop1 ~= pop0 then
            g.show("2. pop0,pop1 "..pop0..","..pop1)
            return
        end
        patt1, patt0 = g.getcells(rect1), patt1
        g.putcells(patt0, 0, 0, 1, 0, 0, 1, "or")
        g.putcells(patt0, 0, 0, 1, 0, 0, 1, "xor")
        local pop2 = 0 + g.getpop()
        if pop2 ~= pop1 then
            --I do not expect glider histories would intersect ... I would miss these cases
            g.show("3. pop0,pop1 "..pop0..","..pop1)
            return
        end
    end
    dirsignx = (((rect1[3]-rect0[3]) == 0) and 1 or 0)*(rect1[1]-rect0[1]<0 and 1 or -1)
    dirsigny = (((rect1[4]-rect0[4]) == 0) and 1 or 0)*(rect1[2]-rect0[2]<0 and 1 or -1)
end

local function classify_parallel_gliders()
    local patt = g.getcells(g.getrect())
    local pop = 0 + g.getpop()
    local gen = 0 + g.getgen()
    if pop ~= 10 then
        g.note("Expecting pattern with 2 gliders")
        return
    end
    if gen ~= 0 then
        g.note("Expecting generation 0")
        return
    end
    local rect0 = g.getrect()
    g.setbase(2)
    g.setstep(6)
    g.step()
    local rect1 = g.getrect()
    if (rect1[3] - rect0[3])~=0 or (rect1[4] - rect0[4])~=0 then
        g.note("Expecting paralel gliders 1")
        return
    end
    g.step()
    local rect1 = g.getrect()
    if (rect1[3] - rect0[3])~=0 or (rect1[4] - rect0[4])~=0 then
        g.note("Expecting paralel gliders 2")
        return
    end
    if (rect1[1] == rect0[1]) or (rect1[2] == rect0[2]) then
        g.note("Expecting moving pattern")
        return
    end
    local dirsignx, dirsigny = (rect1[1]>rect0[1]) and -1 or 1, (rect1[2]>rect0[2]) and -1 or 1
    local gc,gs,gp,gd={},{},{},{}
    local frontx,fronty,backx,backy=rect1[1]+((1-dirsignx)//2)*(rect1[3]-1),rect1[2]+((1-dirsigny)//2)*(rect1[4]-1),rect1[1]+((1+dirsignx)//2)*(rect1[3]-1),rect1[2]+((1+dirsigny)//2)*(rect1[4]-1)
    if g.getcell(frontx + dirsignx,fronty)==1 and g.getcell(frontx,fronty + dirsigny)==1 then
        gc[1+#gc] = {frontx + dirsignx, fronty + dirsigny}
        gc[1+#gc] = {backx - dirsignx, backy - dirsigny}
    else
        gc[1+#gc] = {frontx + dirsignx, backy - dirsigny}
        gc[1+#gc] = {backx - dirsignx, fronty + dirsigny}
    end
    local gen = 0 + g.getgen()
    for i=1,#gc do
        gd[i] = ((dirsigny>0) and "N" or "S")..((dirsignx>0) and "W" or "E")
        if g.getcell(gc[i][1] + dirsignx, gc[i][2]) == 1 then
            gp[i],gs[i] = 0,{gc[i][1] - 1 + dirsignx * (gen // 4), gc[i][2] - 1 + dirsigny * (gen // 4)}
        elseif g.getcell(gc[i][1] - dirsignx, gc[i][2] + dirsigny) == 1 then
            gp[i],gs[i] = 3,{gc[i][1] - 1 + dirsignx * (1 + (gen // 4)), gc[i][2] - 1 + dirsigny * (1 + (gen // 4))}
        end
        if g.getcell(gc[i][1], gc[i][2] + dirsigny) == 1 then
            gp[i],gs[i] = 2,{gc[i][1] -1 + dirsignx * (1 + (gen // 4)), gc[i][2] - 1 + dirsigny * (gen // 4)}
        elseif g.getcell(gc[i][1] + dirsignx, gc[i][2] - dirsigny) == 1 then
            gp[i],gs[i] = 1,{gc[i][1] - 1 + dirsignx * (1 + (gen // 4)), gc[i][2] - 1 + dirsigny * (gen // 4)}
        end
    end
    -- glider[gp].t(gs) is the position at generation 0
    g.show("f={"..frontx..","..fronty.."},b={"..backx..","..backy.."},gc={{"..gc[1][1]..","..gc[1][2].."},{"..gc[2][1]..","..gc[2][2].."}}"..(gp[1] or "n")..(gp[2] or "n")..gd[1]..gd[2])
    --g.note((gp[1] or "n")..gp[2] or "n")
    g.show("gc={{"..gc[1][1]..","..gc[1][2].."},{"..gc[2][1]..","..gc[2][2].."}} gp={"..gp[1]..","..gp[2].."} gs={{"..gs[1][1]..","..gs[1][2].."},{"..gs[2][1]..","..gs[2][2].."}}, gd={"..gd[1]..","..gd[2].."}")
    local xdelta, ydelta = (gs[2][1] - gs[1][1])*dirsignx, (gs[2][2] - gs[1][2])*dirsigny
    local xpydelta, ymxdelta = xdelta + ydelta, ydelta - xdelta
    local lanedist,delay
    local delayx,delayy = 4*xdelta+(gp[1]-gp[2]), 4*ydelta+(gp[1]-gp[2])
    lanedist,delay=ymxdelta,2*xpydelta+(gp[1]-gp[2])
    g.show(delay.." "..lanedist.." "..delayx.." "..delayy.." "..xdelta.." "..ydelta.." "..xpydelta.." "..ymxdelta.." "..dirsignx.." "..dirsigny)
    if delay<0 then
        delay,delayx,delayy=-delay,-delayy,-delayx
    end
    --actually we are searching for the splitter up to trivial transformations so let us standardize the flip around the diagonal
    return lanedist,{delayx,delayy},delay
end

local function combined_splitter_valid(rlestr)
    local save_dirsignx,save_dirsigny = dirsignx, dirsigny
    todebug = false
    classify_2splitter_dirs(rlestr)
    if dirsignx*dirsignx+dirsigny*dirsigny ~= 2 then
        --g.fit()
        --g.update()
        --g.note("dirsigns=("..dirsignx..","..dirsigny..")")
        dirsignx,dirsigny = save_dirsignx,save_dirsigny
        return false
    end
    g.new("check_combined_splitter")
    g.setrule("Life")
    g.setbase(2)
    g.putcells(g.parse(rlestr))
    g.setstep(10)
    g.step()
    g.setgen(0)
    local lanedist,delays,delay=classify_parallel_gliders()
    if (math.abs(lanedist)~=math.abs(tgt_lanedist)) or (delay~=tgt_delay) then
        todebug = true
        --g.fit()
        --g.update()
        --g.note("delay="..delay.." lanedst="..lanedist.." tgt:"..tgt_delay.." "..tgt_lanedist)
        dirsignx,dirsigny = save_dirsignx,save_dirsigny
        return false
    end
    dirsignx,dirsigny = save_dirsignx,save_dirsigny
    return true
end

local function process_combined_turner(tcost,cost,rlestr,dirstr,cathegory,cathegory2,x0,y0,x1,y1,p0,p1,tperiod,period)
    local total_cost=tcost+cost
    local ok = combined_splitter_valid(rlestr)
    if ok then
        if max_total_cost>total_cost+total_cost_range then
            max_total_cost = total_cost+total_cost_range
        end
    end
    if not ok then -- for debugging
        cathegory = cathegory + 16
        if todebug then
            cathegory = cathegory + 16
        end
    end
    if ok or false then -- true for debugging
        outputs[1+#outputs]={cathegory,cathegory2,total_cost,total_cost .. ";cathegory=" .. cathegory .. ";cathegeory2="..cathegory2..";tcost=" .. tcost ..
        ";x0="..x0..";y0="..y0..
        ";ph0%4="..inttostring(p0)..";"..dirstr..";x1="..x1..";y1="..y1..";ph1%4="..inttostring(p1)..";" .. dirstr..
        ";p"..(period == 2 and 2 or tperiod) ..";".. rlestr}
    end
end

local function combine_splittersParallel(cost, rlestr)
    if cost + min_turner_cost > max_total_cost then -- we reached portion of the file which cannot be usefull
        g.show(cost.." splitters_parallel ... we reached portion of the file which cannot be usefull")
        return true
    end
    classify_2splitter_dirs(rlestr)
    g.new("classify_2splittersParallel")
    g.setrule("Life")
    g.setbase(2)
    local startx, starty = locate_start_glider_center(rlestr)
    g.putcells(g.parse(rlestr), -startx, -starty)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    local pattNoGlider = g.getcells(g.getrect())
    g.setstep(0)
    g.step()
    g.putcells(pattNoGlider, 0, 0, 1, 0, 0, 1, "xor")
    local period = (0 + g.getpop() == 0) and 1 or 2
    g.new("classify_2splittersParallel")
    g.setbase(2)
    g.putcells(pattNoGlider)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    g.setstep(10)
    g.step()
    g.setstep(6)
    local rect0 = g.getrect()
    local pop0 = 0 + g.getpop()
    if pop0 % 5 ~= 0 or pop0 == 0 then
        g.note("A2")
        return
    end
    local patt0 = g.getcells(rect0)
    g.step()
    local rect1 = g.getrect()
    if not rect1 then
        g.note("B2")
        return
    end
    local pop1 = 0 + g.getpop()
    if pop1 ~= pop0 then
        g.note("C2")
        return
    end
    local gliderCnt = pop0 / 5
    if gliderCnt ~= 2 then
        g.note("gldercount")
        return
    end
    local patt1 = g.getcells(rect1)
    while rect1[3] - rect0[3] ~= 0 or rect1[4] - rect0[4] ~= 0 do
        g.step()
        g.update()
        rect1, rect0 = g.getrect(), rect1
        if not rect1 then
            g.note("D2")
            return
        end
        pop1 = 0 + g.getpop()
        if pop1 ~= pop0 then
            g.note("E2")
            return
        end
    end
    if ((rect0[2] - rect1[2]) * dirsigny < 0) or ((rect0[1] - rect1[1]) * dirsignx < 0) then
        g.note("G2")
        return
    end
    local gc,gsc,gp,gd,gds={},{},{},{},{}
    local frontx,fronty,backx,backy=rect1[1]+((1-dirsignx)//2)*(rect1[3]-1),rect1[2]+((1-dirsigny)//2)*(rect1[4]-1),rect1[1]+((1+dirsignx)//2)*(rect1[3]-1),rect1[2]+((1+dirsigny)//2)*(rect1[4]-1)
    g.show("f={"..frontx..","..fronty.."},b={"..backx..","..backy.."}")
    if g.getcell(frontx + dirsignx,fronty)==1 and g.getcell(frontx,fronty + dirsigny)==1 then
        gc[1+#gc] = {frontx + dirsignx, fronty + dirsigny}
        gc[1+#gc] = {backx - dirsignx, backy - dirsigny}
    else
        gc[1+#gc] = {backx - dirsignx, fronty + dirsigny}
        gc[1+#gc] = {frontx + dirsignx, backy - dirsigny}
    end
    local gen = 0 + g.getgen()
    for i=1,#gc do
        gd[i],gds[i] = ((dirsigny>0) and "N" or "S")..((dirsignx>0) and "W" or "E"),{dirsignx,dirsigny}
        if g.getcell(gc[i][1] + dirsignx, gc[i][2]) == 1 then
            gp[i],gsc[i] = 0,{gc[i][1] + dirsignx * (gen // 4), gc[i][2] + dirsigny * (gen // 4)}
        elseif g.getcell(gc[i][1] - dirsignx, gc[i][2] + dirsigny) == 1 then
            gp[i],gsc[i] = 3,{gc[i][1] + dirsignx * (1 + (gen // 4)), gc[i][2] + dirsigny * (1 + (gen // 4))}
        end
        if g.getcell(gc[i][1], gc[i][2] + dirsigny) == 1 then
            gp[i],gsc[i] = 2,{gc[i][1] + dirsignx * (1 + (gen // 4)), gc[i][2] + dirsigny * (gen // 4)}
        elseif g.getcell(gc[i][1] + dirsignx, gc[i][2] - dirsigny) == 1 then
            gp[i],gsc[i] = 1,{gc[i][1] + dirsignx * (1 + (gen // 4)), gc[i][2] + dirsigny * (gen // 4)}
        end
    end
    local xdelta, ydelta = gsc[2][1] - gsc[1][1], gsc[2][2] - gsc[1][2]
    local lanedist, dirdist
    if dirsignx==dirsigny then --main diagonal
        lanedist = (xdelta - ydelta)*dirsigny -- positive "above diagonal"
        dirdist =  (ydelta + xdelta)*dirsigny -- 2nd distance delay to 1st
    else
        lanedist = (-xdelta - ydelta)*dirsigny -- positive "above diagonal"
        dirdist = (ydelta - xdelta)*dirsigny   -- 2nd distance delay to 1st
    end

    for ld_sgn=-1,1,2 do -- 2 4               2 4 4 2 4
        for del_sgn=-1,1,2 do -- -2 2       -2-2-2 2 2
            for gl_i=1,2 do -- 1 2        1 1 2 2 1
                local req_delay, req_lanechange  = tgt_delay * del_sgn - (dirdist * 2 * (2*gl_i-3) + gp[3-gl_i] - gp[gl_i]), tgt_lanedist * ld_sgn - (lanedist * (3-2*gl_i))
                local turner_sel = inttostring(req_lanechange).."x"..inttostring(req_delay)
                g.show("xdelta="..xdelta.."ydelta="..ydelta..", req_lanechange="..req_lanechange..", tgt_lanedist "..tgt_lanedist..", req_delay"..req_delay..
                        ", tgt_delay "..tgt_delay.." del_sgn="..del_sgn.." ld_sgn="..ld_sgn.." gl_="..gl_i.."gp={"..gp[1]..","..gp[2].."} dd="..dirdist..
                        " ld="..lanedist.." turner_sel="..turner_sel.."dirsign={"..dirsignx..","..dirsigny.."}")
                if turners[turner_sel] then
                    for t_i = 1,#turners[turner_sel] do
                        local tcost,scx,scy,phase,tperiod,turnerrle = turners[turner_sel][t_i][1],turners[turner_sel][t_i][2],turners[turner_sel][t_i][3],
                        turners[turner_sel][t_i][4],turners[turner_sel][t_i][5],turners[turner_sel][t_i][6]
                        --lanedist would be crrect, we have to position the turner to get the correct delay
                        local totalcost=cost+tcost
                        if totalcost>max_total_cost then
                            break
                        end
                        local delay_turn0 = 2*(scx + scy) - phase
                        local tgx0,tgy0 = locate_start_glider_center(turnerrle)
                        local tpatt = remove_glider_phase(turnerrle,tgx0,tgy0,gp[gl_i])
                        local noShift_tr={gds[gl_i][1],0,0,gds[gl_i][2]}
                        local poss_corr, binary = 80, 128 -- binary search...
                        while (true) do
                            g.new("combine splitters")
                            g.putcells(pattNoGlider,0,0,1,0,0,1)
                            g.putcells(glider, start_shift-1, start_shift-1, 1, 0, 0, 1, "xor")
                            --g.note("sc={"..scx..","..scy.."} phase="..phase.." delay_turn0="..delay_turn0.." delay_corr="..delay_corr)
                            g.putcells(tpatt,gsc[gl_i][1]-poss_corr*gds[gl_i][1],gsc[gl_i][2]-poss_corr*gds[gl_i][2],noShift_tr[1],noShift_tr[2],noShift_tr[3],noShift_tr[4])
                            --g.fit()
                            --g.update()
                            --g.note("testing with turner of cost "..tcost.." binary "..binary)
                            if noShift_tr[1]*noShift_tr[2]+noShift_tr[3]*noShift_tr[4]~=0 then
                                g.update()
                                g.note("weird tranfsorm A! "..noShift_tr[1].." "..noShift_tr[2].." "..noShift_tr[3].." "..noShift_tr[4])
                            end
                            local rlestr=get_rle()
                            if combined_splitter_valid(rlestr) then
                                poss_corr = poss_corr - binary
                            else
                                if todebug then
                                    g.note("wrong pair position")
                                end
                                if poss_corr==80 then -- no chance for improvement the other glider collides with turner enveope (rather to envelopes interferng)
                                    break
                                end
                                poss_corr = poss_corr + binary
                            end
                            if binary == 1 then
                                poss_corr=1+poss_corr
                                break
                            end
                            binary = binary / 2
                        end
                        local new_gsc,new_gp={{gsc[1][1],gsc[1][2]},{gsc[2][1],gsc[2][2]}},{gp[1],gp[2]}
                        --g.note("splitters "..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]+scx*noShift_tr[1]+scy*noShift_tr[2], new_gsc[gl_i][2]+scx*noShift_tr[3]+scy*noShift_tr[4]
                        --g.note("immediate turn "..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gp[gl_i]=new_gp[gl_i]+phase
                        if new_gp[gl_i]>3 then
                            new_gp[gl_i]=new_gp[gl_i]-4
                            new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]-gds[3-gl_i][1],new_gsc[gl_i][2]-gds[3-gl_i][2]
                        end
                        --g.note("phase normalisation"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        local xstart_shift,ystart_shift=start_shift*(gds[3-gl_i][1]-1),start_shift*(gds[3-gl_i][2]-1)
                        new_gsc[1][1],new_gsc[1][2]=new_gsc[1][1]+xstart_shift,new_gsc[1][2]+ystart_shift
                        new_gsc[2][1],new_gsc[2][2]=new_gsc[2][1]+xstart_shift,new_gsc[2][2]+ystart_shift --correction by longer startng glder distance
                        --g.note("start shifting"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        local x0,y0,x1,y1=inttostring(new_gsc[1][1]),inttostring(new_gsc[1][2]),inttostring(new_gsc[2][1]),inttostring(new_gsc[2][2])
                        --g.note(scx.." "..scy.." "..del_sgn.." "..gl_i.." "..ld_sgn.." "..gsc[gl_i][1].." "..gsc[gl_i][2].." "..x0.." "..y0.." "
                        --        ..xstart_shift.." "..ystart_shift.." "..noShift_tr[1].." "..noShift_tr[2].." "..noShift_tr[3].." "..noShift_tr[4].." "..dirsignx.." "..dirsigny.." "..delay_corr)
                        g.new("combine splitters")
                        g.putcells(pattNoGlider,0,0,1,0,0,1)
                        g.putcells(glider, start_shift-1, start_shift-1, 1, 0, 0, 1, "xor")
                        --g.note("sc={"..scx..","..scy.."} phase="..phase.." delay_turn0="..delay_turn0.." delay_corr="..delay_corr)
                        g.putcells(tpatt,gsc[gl_i][1]-poss_corr*gds[gl_i][1],gsc[gl_i][2]-poss_corr*gds[gl_i][2],noShift_tr[1],noShift_tr[2],noShift_tr[3],noShift_tr[4])
                        g.fit()
                        g.update()
                        local rlestr=get_rle()
                        --g.note("turner processing starts with #outputs="..#outputs)
                        process_combined_turner(tcost,cost,rlestr,gd[3-gl_i],4*gds[3-gl_i][1]+2*gds[3-gl_i][2]+((math.abs(x0-x1)>math.abs(y0-y1)) and 1 or 0), 2*ld_sgn+del_sgn+gl_i,
                                x0,y0,x1,y1,new_gp[1],new_gp[2],tperiod,period)
                        --g.note("turner processing ends with #outputs="..#outputs)
                    end
                end
            end
        end
    end
end

local function combine_splittersOpposite(cost, rlestr)
    if cost + min_turner_cost > max_total_cost then -- we reached portion of the file which cannot be usefull
        g.show(cost.." splitters_opposite ... we reached portion of the file which cannot be usefull")
        return true
    end
    dirsignx,dirsigny = 0,0
    g.new("classify_2splittersOpposite")
    g.setrule("Life")
    g.setbase(2)
    local startx, starty = locate_start_glider_center(rlestr)
    g.putcells(g.parse(rlestr), -startx, -starty)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    local pattNoGlider = g.getcells(g.getrect())
    g.setstep(0)
    g.step()
    g.putcells(pattNoGlider, 0, 0, 1, 0, 0, 1, "xor")
    local period = (0 + g.getpop() == 0) and 1 or 2
    g.new("classify_2splittersOpposite")
    g.setbase(2)
    g.putcells(pattNoGlider)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    g.setstep(10)
    g.step()
    g.setstep(6)
    local rect0 = g.getrect()
    local pop0 = 0 + g.getpop()
    if pop0 % 5 ~= 0 or pop0 == 0 then
        g.note("A3")
        return
    end
    local patt0 = g.getcells(rect0)
    g.step()
    local rect1 = g.getrect()
    if not rect1 then
        g.note("B3")
        return
    end
    local pop1 = 0 + g.getpop()
    if pop1 ~= pop0 then
        g.note("C3")
        return
    end
    local gliderCnt = pop0 / 5
    if gliderCnt ~= 2 then
        g.note("gldercount")
        return
    end
    local patt1 = g.getcells(rect1)
    while rect1[3] - rect0[3] ~= 32 or rect1[4] - rect0[4] ~= 32 do
        g.step()
        g.update()
        rect1, rect0 = g.getrect(), rect1
        if not rect1 then
            g.note("D3")
            return
        end
        pop1 = 0 + g.getpop()
        if pop1 ~= pop0 then
            g.note("E3")
            return
        end
    end
    local gc,gsc,gp,gd,gds={},{},{},{},{}
    local dirx,diry=1,1 -- main diagonal
    local frontx,fronty,backx,backy=rect1[1],rect1[2],rect1[1]+(rect1[3]-1),rect1[2]+(rect1[4]-1)
    if (g.getcell(frontx + 1, fronty)~=1) or (g.getcell(frontx, fronty+1)~=1) then
        dirx, frontx, backx = -1, backx, frontx
    end
    g.show("f={"..frontx..","..fronty.."},b={"..backx..","..backy.."}")
    gc[1+#gc] = {frontx + dirx, fronty + 1}
    gc[1+#gc] = {backx - dirx, backy - 1}
    local gen = 0 + g.getgen()
    for i=1,#gc do
        gd[i],gds[i] = ((i==1) and "N" or "S")..((dirx>0) and "W" or "E"),{dirx,diry}
        if g.getcell(gc[i][1] + dirx, gc[i][2]) == 1 then
            gp[i],gsc[i] = 0,{gc[i][1] + dirx * (gen // 4), gc[i][2] + diry * (gen // 4)}
        elseif g.getcell(gc[i][1] - dirx, gc[i][2] + diry) == 1 then
            gp[i],gsc[i] = 3,{gc[i][1] + dirx * (1 + (gen // 4)), gc[i][2] + diry * (1 + (gen // 4))}
        end
        if g.getcell(gc[i][1], gc[i][2] + diry) == 1 then
            gp[i],gsc[i] = 2,{gc[i][1] + dirx * (1 + (gen // 4)), gc[i][2] + diry * (gen // 4)}
        elseif g.getcell(gc[i][1] + dirx, gc[i][2] - diry) == 1 then
            gp[i],gsc[i] = 1,{gc[i][1] + dirx * (1 + (gen // 4)), gc[i][2] + diry * (gen // 4)}
        end
        dirx,diry=-dirx,-diry --flipping, the other glider has opposite direction
    end
    local xdelta, ydelta = gsc[2][1] - gsc[1][1], gsc[2][2] - gsc[1][2]
    local lanedist, dirdist
    if dirx==1 then --main diagonal
        lanedist = xdelta - ydelta -- positive "above diagonal"
        dirdist =  ydelta + xdelta -- negative before, positive after crossing
    else
        lanedist = -xdelta - ydelta -- positive "above diagonal"
        dirdist = ydelta - xdelta   -- negative before, positive after crossing
    end
    for ld_sgn=-1,1,2 do -- 2 4               2 4 4 2 4
        local req_lanechange = tgt_lanedist * ld_sgn - lanedist
        for del_sgn=-1,1,2 do -- -2 2       -2-2-2 2 2
            for gl_i=1,2 do -- 1 2        1 1 2 2 1
                local req_delay = tgt_delay * del_sgn - (dirdist * 2 + gp[3-gl_i] - gp[gl_i])
                local turner_sel = 8 * req_lanechange + (req_delay)%8
                g.show("xdelta="..xdelta.."ydelta="..ydelta..", req_lanechange="..req_lanechange..", tgt_lanedist "..tgt_lanedist..", req_delay"..req_delay..
                        ", tgt_delay "..tgt_delay.." del_sgn="..del_sgn.." ld_sgn="..ld_sgn.." gl_="..gl_i.."gp={"..gp[1]..","..gp[2].."} dd="..dirdist.." ld="..lanedist.." turner_sel="..turner_sel)
                if turners[turner_sel] then
                    for t_i = 1,#turners[turner_sel] do
                        local tcost,scx,scy,phase,tperiod,turnerrle = turners[turner_sel][t_i][1],turners[turner_sel][t_i][2],turners[turner_sel][t_i][3],
                        turners[turner_sel][t_i][4],turners[turner_sel][t_i][5],turners[turner_sel][t_i][6]
                        --lanedist would be crrect, we have to position the turner to get the correct delay
                        local totalcost=cost+tcost
                        if totalcost>max_total_cost then
                            break
                        end
                        local delay_turn0 = -2*(scx + scy) - phase
                        local delay_corr = (req_delay - delay_turn0)/8
                        local tgx0,tgy0 = locate_start_glider_center(turnerrle)
                        local tpatt = remove_glider_phase(turnerrle,tgx0,tgy0,gp[gl_i])
                        g.new("combine splitters")
                        g.putcells(pattNoGlider,0,0,1,0,0,1)
                        g.putcells(glider, start_shift-1, start_shift-1, 1, 0, 0, 1, "xor")
                        --g.note("sc={"..scx..","..scy.."} phase="..phase.." delay_turn0="..delay_turn0.." delay_corr="..delay_corr)
                        local noShift_tr={gds[gl_i][1],0,0,gds[gl_i][2]}
                        g.putcells(tpatt,gsc[gl_i][1]-delay_corr*gds[gl_i][1],gsc[gl_i][2]-delay_corr*gds[gl_i][2],noShift_tr[1],noShift_tr[2],noShift_tr[3],noShift_tr[4])
                        if noShift_tr[1]*noShift_tr[2]+noShift_tr[3]*noShift_tr[4]~=0 then
                            g.update()
                            g.note("weird tranfsorm B! "..noShift_tr[1].." "..noShift_tr[2].." "..noShift_tr[3].." "..noShift_tr[4])
                        end
                        local new_gsc,new_gp={{gsc[1][1],gsc[1][2]},{gsc[2][1],gsc[2][2]}},{gp[1],gp[2]}
                        --g.note("splitters "..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]+scx*noShift_tr[1]+scy*noShift_tr[2], new_gsc[gl_i][2]+scx*noShift_tr[3]+scy*noShift_tr[4]
                        --g.note("immediate turn "..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gp[gl_i]=new_gp[gl_i]+phase
                        if new_gp[gl_i]>3 then
                            new_gp[gl_i]=new_gp[gl_i]-4
                            new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]-gds[3-gl_i][1],new_gsc[gl_i][2]-gds[3-gl_i][2]
                        end
                        --g.note("phase normalisation"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]-2*delay_corr*gds[gl_i][1],
                        new_gsc[gl_i][2]-2*delay_corr*gds[gl_i][2]
                        --g.note("turn repositioning"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        local xstart_shift,ystart_shift=start_shift*(gds[3-gl_i][1]-1),start_shift*(gds[3-gl_i][2]-1)
                        new_gsc[1][1],new_gsc[1][2]=new_gsc[1][1]+xstart_shift,new_gsc[1][2]+ystart_shift
                        new_gsc[2][1],new_gsc[2][2]=new_gsc[2][1]+xstart_shift,new_gsc[2][2]+ystart_shift --correction by longer startng glder distance
                        --g.note("start shifting"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        local x0,y0,x1,y1=inttostring(new_gsc[1][1]),inttostring(new_gsc[1][2]),inttostring(new_gsc[2][1]),inttostring(new_gsc[2][2])
                        --g.note(scx.." "..scy.." "..del_sgn.." "..gl_i.." "..ld_sgn.." "..gsc[gl_i][1].." "..gsc[gl_i][2].." "..x0.." "..y0.." "
                        --        ..xstart_shift.." "..ystart_shift.." "..noShift_tr[1].." "..noShift_tr[2].." "..noShift_tr[3].." "..noShift_tr[4].." "..dirsignx.." "..dirsigny.." "..delay_corr)
                        local rlestr=get_rle()
                        process_combined_turner(tcost,cost,rlestr,gd[3-gl_i],4*gds[3-gl_i][1]+2*gds[3-gl_i][2]+((math.abs(x0-x1)>math.abs(y0-y1)) and 1 or 0), 16+2*ld_sgn+del_sgn+gl_i,
                                x0,y0,x1,y1,new_gp[1],new_gp[2],tperiod,period)
                    end
                end
            end
        end
    end
end

local function combine_splittersPerp(cost, rlestr)
    if cost + min_turner_cost > max_total_cost then -- we reached portion of the file which cannot be usefull
        g.show(cost.." splitters_perp ... we reached portion of the file which cannot be usefull")
        return true
    end
    classify_2splitter_dirs(rlestr)
    if dirsignx*dirsigny~=0 then
        g.note("strange dir detection "..dirsignx.." "..dirsigny)
    end
    g.new("classify_2splittersPerp")
    g.setrule("Life")
    g.setbase(2)
    local startx, starty = locate_start_glider_center(rlestr)
    g.putcells(g.parse(rlestr), -startx, -starty)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    local pattNoGlider = g.getcells(g.getrect())
    --g.note("positioned!")
    g.setstep(0)
    g.step()
    g.putcells(pattNoGlider, 0, 0, 1, 0, 0, 1, "xor")
    local period = (0 + g.getpop() == 0) and 1 or 2
    g.new("classify_2splittersPerp")
    g.setbase(2)
    g.putcells(pattNoGlider)
    g.putcells(glider, -1, -1, 1, 0, 0, 1, "xor")
    g.setstep(10)
    g.step()
    g.setstep(6)
    local rect0 = g.getrect()
    local pop0 = 0 + g.getpop()
    if pop0 % 5 ~= 0 or pop0 == 0 then
        g.note("A4")
        return
    end
    local patt0 = g.getcells(rect0)
    g.step()
    local rect1 = g.getrect()
    if not rect1 then
        g.note("B4")
        return
    end
    local pop1 = 0 + g.getpop()
    if pop1 ~= pop0 then
        g.note("C4")
        return
    end
    local gliderCnt = pop0 / 5
    if gliderCnt ~= 2 then
        g.note("gldercount")
        return
    end
    local patt1 = g.getcells(rect1)
    while (rect1[3] - rect0[3])~=32*dirsigny*dirsigny or (rect1[4] - rect0[4])~=32*dirsignx*dirsignx do
        g.note((rect1[3] - rect0[3]).." "..(rect1[4] - rect0[4]).." "..dirsignx.." "..dirsigny)
        g.step()
        g.update()
        rect1, rect0 = g.getrect(), rect1
        if not rect1 then
            g.note("D4")
            return
        end
        pop1 = 0 + g.getpop()
        if pop1 ~= pop0 then
            g.note("E4")
            return
        end
    end
    local gc,gsc,gp,gd,gds={},{},{},{},{}
    local dirx,diry=dirsignx+dirsigny*dirsigny,dirsigny+dirsignx*dirsignx
    local frontx,fronty,backx,backy=rect1[1]+((1-dirx)//2)*(rect1[3]-1),rect1[2]+((1-diry)//2)*(rect1[4]-1),rect1[1]+((1+dirx)//2)*(rect1[3]-1),rect1[2]+((1+diry)//2)*(rect1[4]-1)
    g.show("f={"..frontx..","..fronty.."},b={"..backx..","..backy.."}")
    if g.getcell(frontx + dirx,fronty)~=1 or g.getcell(frontx,fronty + diry)~=1 then
        dirx,diry=dirsignx-dirsigny*dirsigny,dirsigny-dirsignx*dirsignx
        frontx,fronty,backx,backy=rect1[1]+((1-dirx)//2)*(rect1[3]-1),rect1[2]+((1-diry)//2)*(rect1[4]-1),rect1[1]+((1+dirx)//2)*(rect1[3]-1),rect1[2]+((1+diry)//2)*(rect1[4]-1)
    end
    gc[1+#gc] = {frontx + dirx, fronty + diry}
    gc[1+#gc] = {backx - dirx, backy - diry} -- perp direction
    local gen = 0 + g.getgen()
    for i=1,#gc do
        gd[i],gds[i] = ((diry>0) and "N" or "S")..((dirx>0) and "W" or "E"),{dirx,diry}
        if g.getcell(gc[i][1] + dirx, gc[i][2]) == 1 then
            gp[i],gsc[i] = 0,{gc[i][1] + dirx * (gen // 4), gc[i][2] + diry * (gen // 4)}
        elseif g.getcell(gc[i][1] - dirx, gc[i][2] + diry) == 1 then
            gp[i],gsc[i] = 3,{gc[i][1] + dirx * (1 + (gen // 4)), gc[i][2] + diry * (1 + (gen // 4))}
        end
        if g.getcell(gc[i][1], gc[i][2] + diry) == 1 then
            gp[i],gsc[i] = 2,{gc[i][1] + dirx * (1 + (gen // 4)), gc[i][2] + diry * (gen // 4)}
        elseif g.getcell(gc[i][1] + dirx, gc[i][2] - diry) == 1 then
            gp[i],gsc[i] = 1,{gc[i][1] + dirx * (1 + (gen // 4)), gc[i][2] + diry * (gen // 4)}
        end
        dirx,diry=dirx*(1-2*dirsigny*dirsigny),diry*(1-2*dirsignx*dirsignx) --the perp dir
    end
    local order
    --g.show("f={"..frontx..","..fronty.."},b={"..backx..","..backy.."},gc={{"..gc[1][1]..","..gc[1][2].."},{"..gc[2][1]..","..gc[2][2].."}}"..(gp[1] or "n")..gd[1]..(gp[2] or "n")..gd[2]..dirsignx..dirsigny..dirx..diry)
    --g.note((gp[1] or "n")..gp[2] or "n")
    --g.show("gc={{"..gc[1][1]..","..gc[1][2].."},{"..gc[2][1]..","..gc[2][2].."}} gp={"..gp[1]..","..gp[2].."} gs={{"..gs[1][1]..","..gs[1][2].."},{"..gs[2][1]..","..gs[2][2].."}} gd={"..gd[1]..","..gd[2].."}")
    local xdelta, ydelta = gsc[2][1] - gsc[1][1], gsc[2][2] - gsc[1][2]
    --local xpydelta, ymxdelta = xdelta + ydelta, ydelta - xdelta
    --local linedist,delay
    local delay, colorchange
    if dirsignx~=0 then --horizontal
        delay, colorchange = 4*xdelta*dirsignx+gp[1]-gp[2], (xdelta + ydelta + tgt_lanedist)%2
    else
        delay, colorchange = 4*ydelta*dirsigny+gp[1]-gp[2], (xdelta + ydelta + tgt_lanedist)%2
    end
    local base_lanedists = {xdelta*gds[1][1] + ydelta*gds[1][2], - xdelta*gds[2][1] - ydelta*gds[2][2]} --dist grows when glider (to turn) moves its direction indexed by the turning glider.
    for del_i=1,2 do -- 2 4               2 4 4 2 4
        for sign=-1,1,2 do -- -2 2       -2-2-2 2 2
            for gl_i=1,2 do -- 1 2        1 1 2 2 1
                local req_delay=delay*(3-2*gl_i)+sign*tgt_delays[del_i]
                g.show("xdelta="..xdelta.."ydelta="..ydelta..", tgt_delays[del_i="..del_i.."]="..tgt_delays[del_i]..", tgt_lanedist "..tgt_lanedist..", delay"..delay..
                        ", colorchange "..colorchange..", base_lane_dists[gl_i="..gl_i.."]="..base_lanedists[gl_i])
                local turner_sel=2*req_delay+colorchange -- appropriate delay in front direction
                if turners[turner_sel] then
                    local split_line_dist0 = gsc[gl_i][1]; --relative to finished glider (2)
                    for t_i = 1,#turners[turner_sel] do
                        local tcost,scx,scy,phase,tperiod,turnerrle = turners[turner_sel][t_i][1],turners[turner_sel][t_i][2],turners[turner_sel][t_i][3],
                        turners[turner_sel][t_i][4],turners[turner_sel][t_i][5],turners[turner_sel][t_i][6]
                        --scx,scy,phase is correct in direction gd[3-gl_i], we should chose shift such that tgt_lanedist is achieved (we will try both signs of tgt_lanedist)
                        local totalcost=cost+tcost
                        if totalcost>max_total_cost then
                            break
                        end
                        local lanedist_turn_change0 = base_lanedists[gl_i] - scx - scy
                        local tgx0,tgy0 = locate_start_glider_center(turnerrle)
                        local tpatt = remove_glider_phase(turnerrle,tgx0,tgy0,gp[gl_i])
                        local lanedist_corr = (tgt_lanedist*sign*(2*del_i-3) + lanedist_turn_change0)/2
                        -- case 7 (tgt_lanedist + lanedist_turn_change0 OK)
                        -- case 6 (-tgt_lanedist + lanedist_turn_change0 OK)
                        -- case 1 (tgt_lanedist + lanedist_turn_change0 OK)
                        -- case 3 (-tgt_lanedist + lanedist_turn_change0 OK)
                        -- case 4 (-tgt_lanedist + lanedist_turn_change0 OK)
                        --g.new("combine splitters")
                        --g.putcells(tpatt,0,0,dirx*dirsigny*dirsigny,dirsignx,diry*dirsignx*dirsignx,dirsigny)
                        --g.note("glider center should be at 0,0")
                        g.new("combine splitters")
                        g.putcells(pattNoGlider,0,0,1,0,0,1)
                        g.putcells(glider, start_shift-1, start_shift-1, 1, 0, 0, 1, "xor")
                        local noShift_tr={gds[gl_i][1]*dirsigny*dirsigny,dirsignx,gds[gl_i][2]*dirsignx*dirsignx,dirsigny}
                        g.putcells(tpatt,gsc[gl_i][1]-dirsignx+lanedist_corr*gds[gl_i][1],gsc[gl_i][2]+lanedist_corr*gds[gl_i][2],noShift_tr[1],noShift_tr[2],noShift_tr[3],noShift_tr[4])
                        if noShift_tr[1]*noShift_tr[2]+noShift_tr[3]*noShift_tr[4]~=0 then
                            g.update()
                            g.note("weird tranfsorm C! "..noShift_tr[1].." "..noShift_tr[2].." "..noShift_tr[3].." "..noShift_tr[4].." "..dirsignx.." "..dirsigny)
                        end
                        -- dirsignx corrects the line positioning based on x coord rather to y coord (phase differs by +/-2)
                        local new_gsc,new_gp={{gsc[1][1],gsc[1][2]},{gsc[2][1],gsc[2][2]}},{gp[1],gp[2]}
                        --g.note("splitters "..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]+scx*noShift_tr[1]+scy*noShift_tr[2], new_gsc[gl_i][2]+scx*noShift_tr[3]+scy*noShift_tr[4]
                        --g.note("immediate turn "..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gp[gl_i]=new_gp[gl_i]+phase
                        if new_gp[gl_i]>3 then
                            new_gp[gl_i]=new_gp[gl_i]-4
                            new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]-gds[3-gl_i][1],new_gsc[gl_i][2]-gds[3-gl_i][2]
                        end
                        --g.note("phase normalisation"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        new_gsc[gl_i][1],new_gsc[gl_i][2]=new_gsc[gl_i][1]+lanedist_corr*(gds[gl_i][1]-gds[3-gl_i][1]),
                        new_gsc[gl_i][2]+lanedist_corr*(gds[gl_i][2]-gds[3-gl_i][2])
                        --g.note("turn repositioning"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        local xstart_shift,ystart_shift=start_shift*(gds[3-gl_i][1]-1),start_shift*(gds[3-gl_i][2]-1)
                        new_gsc[1][1],new_gsc[1][2]=new_gsc[1][1]+xstart_shift,new_gsc[1][2]+ystart_shift
                        new_gsc[2][1],new_gsc[2][2]=new_gsc[2][1]+xstart_shift,new_gsc[2][2]+ystart_shift --correction by longer startng glder distance
                        --g.note("start shfting"..new_gsc[gl_i][1].." "..new_gsc[gl_i][2])
                        local x0,y0,x1,y1=inttostring(new_gsc[1][1]),inttostring(new_gsc[1][2]),inttostring(new_gsc[2][1]),inttostring(new_gsc[2][2])
                        --g.note(scx.." "..scy.." "..del_i.." "..gl_i.." "..sign.." "..gsc[gl_i][1].." "..gsc[gl_i][2].." "..x0.." "..y0.." "
                        --        ..xstart_shift.." "..ystart_shift.." "..noShift_tr[1].." "..noShift_tr[2].." "..noShift_tr[3].." "..noShift_tr[4].." "..dirsignx.." "..dirsigny.." "..lanedist_corr)
                        local rlestr=get_rle()
                        process_combined_turner(tcost,cost,rlestr,gd[3-gl_i],4*gds[3-gl_i][1]+2*gds[3-gl_i][2]+((math.abs(x0-x1)>math.abs(y0-y1)) and 1 or 0),32+2*del_i+sign+gl_i,
                                x0,y0,x1,y1,new_gp[1],new_gp[2],tperiod,period)
                    end
                end
            end
        end
    end
    --tgt_lanedist
end

local function set_minimal_costs(turner_fle_name, splitter_file_name)
    local i = io.open(data_infile_dir .. turner_fle_name .. ".txt", "r")
    local inputline = i:read()
    i:close()
    local seppos = string.find(inputline, "%;")
    min_turner_cost = 0 + string.sub(inputline, 1, seppos - 1)
    local i = io.open(data_infile_dir .. splitter_file_name .. ".txt", "r")
    inputline = i:read()
    i:close()
    seppos = string.find(inputline, "%;")
    min_splitter_cost = 0 + string.sub(inputline, 1, seppos - 1)
end

local function process_txtfile(basefilename, process_phase)
    g.show(basefilename)
    --g.note(basefilename)
    local i = io.open(data_infile_dir .. basefilename .. ".txt", "r")
    local inputline = i:read()
    while inputline do
        local seppos = string.find(inputline, "%;")
        local cost, rle = 0 + string.sub(inputline, 1, seppos - 1), string.sub(inputline, seppos + 1)
        if process_phase==0 then
            if (hash_turners(cost,rle)) then
                break
            end
        elseif process_phase==1 then
            if (combine_splittersParallel(cost,rle)) then
                break
            end
        elseif process_phase==2 then
            if (combine_splittersOpposite(cost,rle)) then
                break
            end
        elseif process_phase==3 then
            if (combine_splittersPerp(cost,rle)) then
                break
            end
        end
        inputline = i:read()
    end
    i:close()
end

local function main()
    tgt_lanedist,tgt_delays,tgt_delay=classify_parallel_gliders()
    --g.note(tgt_lanedist .. " " .. tgt_shortdelay .. " " .. tgt_longdelay)

    for rel_dir_i = 1,#rel_dirs do
        local dir_i = rel_dirs[rel_dir_i][2]
        local dir = dirs[dir_i][1]
        dirsignx, dirsigny = dirs[dir_i][2], dirs[dir_i][3]
        local turner_file_name, splitter_file_name = dir.."_turners","2_splitters_"..rel_dirs[rel_dir_i][1]
        set_minimal_costs(turner_file_name, splitter_file_name)
        turners={}
        process_txtfile(turner_file_name, 0)
        process_txtfile(splitter_file_name, rel_dir_i)
    end
    table.sort(outputs, function (k1, k2) for i=1,3 do if k1[i]~=k2[i] then return k1[i]<k2[i] end end end)
    local o =  io.open(data_outfile_dir.."2parallel_gliders_defined_splitter.txt", "w")
    g.note("max_total_cost "..max_total_cost)
    for i=1,#outputs do
        if outputs[i][3]<=max_total_cost then
            o:write(outputs[i][4] .. "\n")
        else
            --g.note("total cost "..outputs[i][3].." max_total_cost "..max_total_cost)
        end
    end
    o:close()
    outputs={}
end

main()