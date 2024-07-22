local g = golly()

local smallobj = {}
local glider = g.parse("2o$obo$o!")
local maxpercriteria2 = 8000
local doublehist = false --true --
local data_file_dir = "c:\\golly\\Patterns\\Workdir\\"

local xstep,ystep
local singleadd,doubleadd
g.autoupdate(true)
g.setoption("savexrle", 0)

if doublehist then
    singleadd,doubleadd=1,2
else
    singleadd,doubleadd=9,4
end

local function inttostring(num)
    return string.sub(num, 1, string.find(num .. ".", "%.") - 1)
end

local function locate_start_glider(rlestr)
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

local function double(x,y)
    g.setcell(x,y,g.getcell(x,y)+doubleadd)
end

local function single(patt)
    local step = 2+(#patt%2)
    for i=1,#patt-1,step do
        g.setcell(patt[i],patt[i+1],g.getcell(patt[i],patt[i+1])+singleadd)
    end
end

local function parseline(line,dir)
    g.show(line)
    local x0, y0, ph0, dir0, x1, y1, ph1, dir1, rle, cost, criteria1, criteria2
    _, _, cost, criteria1, criteria2 =  string.find(line,"([^;]+);[^=]+=([^;]+);[^=]+=([^;]+)")
    g.show((cost or "c").." "..(criteria1 or "c1").." "..(criteria2 or "c2").." "..line)
    _, _, x1, y1, ph1, dir1, rle = string.find(line, "x1=([^;]+);y1=([^;]+);ph1.4=(.);([^;]+);p.;(.*)")
    g.show((cost or "c").." "..(criteria1 or "c1").." "..(criteria2 or "c2").." "..(x1 or "x1").." "..(y1 or "y1").." "..(ph1 or "ph1").." "..(dir1 or "d1").." "..(rle and "" or "rle").." "..line)
    if x1 then -- 2splitter formats
        _, _, x0, y0, ph0, dir0 = string.find(line, "x0=([^;]+);y0=([^;]+);ph0.4=(.);([^;]+)")
    else --turner formats
        _, _, x0, y0, ph0, rle = string.find(line, "x0=([^;]+);y0=([^;]+);[^;]+;[^=]+=(.);(.*)")
        dir0 = dir
    end
    if not x0 then
        cost, rle = string.find(line, "([^;]+);(.*)")
        criteria1, criteria2 = 0,0
    end
    g.show((cost or "c").." "..(criteria1 or "c1").." "..(criteria2 or "c2").." "..(x1 or "x1").." "..(y1 or "y1").." "..(ph1 or "ph1").." "..(dir1 or "d1").." "
            ..(x0 or "x0").." "..(y0 or "y0").." "..(ph0 or "ph0").." "..(dir0 or "d0").." "..(rle and "" or "rle").." "..line)
    local gl={}
    if x0 then
        gl[1]={x0+0,y0+0,ph0+0,dir0}
    end
    if x1 then
        gl[2]={x1+0,y1+0,ph1+0,dir1}
    end
    return cost+0, criteria1+0, criteria2+0, rle, gl
end

local function putrlestr(x,y,rlestr,gl)
    local startx,starty=locate_start_glider(rlestr)
    single(g.parse(rlestr,x-startx,y-starty))
    for i=1,#gl do
        local dirsignx,dirsigny=string.sub(gl[i][4],-1)=="W" and 1 or -1,string.sub(gl[i][4],1,1)=="N" and 1 or -1
        local centerx,centery,ph=x+1+gl[i][1],y+1+gl[i][2],gl[i][3]
        if ph>0 then
            centerx=centerx-dirsignx
            if ph>2 then
                centery=centery-dirsigny
            end
        end
        double(centerx-dirsignx,centery)
        double(centerx,centery-dirsigny)
        if ph==0 then
            double(centerx-dirsignx,centery-1)
            double(centerx-dirsignx,centery+1)
            double(centerx+dirsignx,centery)
        elseif ph==1 then
            double(centerx+dirsignx,centery-1)
            double(centerx+dirsignx,centery+1)
            double(centerx,centery)
        elseif ph==2 then
            double(centerx-1,centery-dirsigny)
            double(centerx+1,centery-dirsigny)
            double(centerx,centery+dirsigny)
        else
            double(centerx-1,centery+dirsigny)
            double(centerx+1,centery+dirsigny)
            double(centerx,centery)
        end
    end
end

local function process_txtfile(basefilename,dir)
    g.new(basefilename)
    if doublehist then
        g.setrule("DoubleOneHist")
    else
        g.setrule("LifeHistory14")
    end
    g.show(basefilename)
    local i = io.open(data_file_dir .. basefilename .. ".txt", "r")
    local inputline = i:read()
    local prevcriteria1,prevcriteria2=99999,99999
    local best1rlestr,best1cost,best1gl
    local showcriteria2count=maxpercriteria2
    local x,y=0,0
    while inputline do
        local cost, criteria1, criteria2, rlestr, gl = parseline(inputline, dir)
        inputline = i:read()
        if prevcriteria2~=criteria2 then
            prevcriteria2,showcriteria2count=criteria2,maxpercriteria2
            x=x+xstep
        end
        if prevcriteria1~=criteria1 then
            if prevcriteria1~=99999 then
                putrlestr(-100,y,best1rlestr,best1gl)
            end
            prevcriteria1=criteria1
            x,y=-xstep,y+ystep
            best1cost,best1rlestr,best1gl=cost,rlestr,gl
        end
        if cost<best1cost then
            best1cost,best1rlestr,best1gl=cost,rlestr,gl
        end
        if showcriteria2count>0 then
            x=x+xstep
            putrlestr(x,y,rlestr,gl)
            showcriteria2count=showcriteria2count-1
        end
    end
    if prevcriteria1~=99999 then
        putrlestr(-100,y,best1rlestr,best1gl)
    end
    i:close()
    g.save(data_file_dir .. basefilename .. (doublehist and "DH" or "") .. ".mc","mc")
end

local function turners()
    xstep,ystep = 40,80
    process_txtfile("0_turners","NW")
    process_txtfile("90_turners","NE")
    process_txtfile("180_turners","SE")
--    process_txtfile("270__turners","SW")
end

local function _turners()
    xstep,ystep = 40,80
    process_txtfile("0__turners","NW")
    process_txtfile("90__turners","NE")
    process_txtfile("180__turners","SE")
    --    process_txtfile("270__turners","SW")
end

local function splitters_2()
    xstep,ystep = 60,120
    process_txtfile("2_splitters_perp")
    process_txtfile("2_splitters_parallel")
    process_txtfile("2_splitters_opposite")
end

local function glider_defined()
    xstep,ystep = 256,256
    process_txtfile("2parallel_gliders_defined_splitter")
end

doublehist = false
--turners()
--splitters_2()
glider_defined()
doublehist = true
--turners()
--splitters_2()
glider_defined()
