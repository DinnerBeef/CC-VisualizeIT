-- Telem by cyberbit
-- MIT License
-- Version 0.5.0

---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------

do
    local searchers = package.searchers or package.loaders
    local origin_seacher = searchers[2]
    searchers[2] = function(path)
        local files =
        {
------------------------
-- Modules part begin --
------------------------

["telem.lib.Backplane"] = function()
--------------------
-- Module: 'telem.lib.Backplane'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter     = require 'telem.lib.InputAdapter'
local OutputAdapter    = require 'telem.lib.OutputAdapter'
local MetricCollection = require 'telem.lib.MetricCollection'

local Backplane = o.class()
Backplane.type = 'Backplane'

function Backplane:constructor ()
    self.debugState = false

    self.inputs = {}
    self.outputs = {}

    -- workaround to guarantee processing order
    self.inputKeys = {}
    self.outputKeys = {}

    -- last recorded state
    self.collection = MetricCollection()

    self.asyncCycleHandlers = {}
end

-- TODO allow auto-named inputs based on type
function Backplane:addInput (name, input)
    assert(type(name) == 'string', 'name must be a string')
    assert(o.instanceof(input, InputAdapter), 'Input must be an InputAdapter')

    -- propagate debug state
    if self.debugState then
        input:debug(self.debugState)
    end

    self.inputs[name] = input
    table.insert(self.inputKeys, name)

    if input.asyncCycleHandler then
        self:addAsyncCycleHandler(name, input.asyncCycleHandler)
    end

    return self
end

function Backplane:addOutput (name, output)
    assert(type(name) == 'string', 'name must be a string')
    assert(o.instanceof(output, OutputAdapter), 'Output must be an OutputAdapter')

    self:dlog('Backplane:addOutput :: adding output: ' .. name)

    -- propagate debug state
    if self.debugState then
        output:debug(self.debugState)
    end

    self.outputs[name] = output
    table.insert(self.outputKeys, name)

    if output.asyncCycleHandler then
        self:dlog('Backplane:addOutput :: registering async handler for ' .. name)

        self:addAsyncCycleHandler(name, function ()
            self:dlog('Backplane:asyncCycleHandler (closure) :: executing async handler for ' .. name)
                
            local results = {pcall(output.asyncCycleHandler, self)}
    
            if not table.remove(results, 1) then
                t.log('Output fault in async handler for "' .. name .. '":')
                t.pprint(table.remove(results, 1))
            end
        end)
    end

    return self
end

function Backplane:addAsyncCycleHandler (adapter, handler)
    table.insert(self.asyncCycleHandlers, handler)
end

-- NYI
function Backplane:processMiddleware ()
    --
    return self
end

function Backplane:cycle()
    local tempMetrics = {}
    local metrics = MetricCollection()

    self:dlog('Backplane:cycle :: ' .. os.date())
    self:dlog('Backplane:cycle :: cycle START !')

    self:dlog('Backplane:cycle :: reading inputs...')

    -- read inputs
    for _, key in ipairs(self.inputKeys) do
        local input = self.inputs[key]

        self:dlog('Backplane:cycle ::  - ' .. key)

        local results = {pcall(input.read, input)}

        if not table.remove(results, 1) then
            t.log('Input fault for "' .. key .. '":')
            t.pprint(table.remove(results, 1))
        else
            local inputMetrics = table.remove(results, 1)

            -- attach adapter name
            for _,v in ipairs(inputMetrics.metrics) do
                v.adapter = key .. (v.adapter and ':' .. v.adapter or '')

                table.insert(tempMetrics, v)
            end
        end
    end

    -- TODO process middleware

    self:dlog('Backplane:cycle :: sorting metrics...')

    -- sort
    -- TODO make this a middleware
    table.sort(tempMetrics, function (a,b) return a.name < b.name end)
    for _,v in ipairs(tempMetrics) do
        metrics:insert(v)
    end

    self:dlog('Backplane:cycle :: saving state...')

    self.collection = metrics

    self:dlog('Backplane:cycle :: writing outputs...')

    -- write outputs
    for _, key in pairs(self.outputKeys) do
        local output = self.outputs[key]

        self:dlog('Backplane:cycle ::  - ' .. key)

        local results = {pcall(output.write, output, metrics)}

        if not table.remove(results, 1) then
            t.log('Output fault for "' .. key .. '":')
            t.pprint(table.remove(results, 1))
        end
    end

    self:dlog('Backplane:cycle :: cycle END !')

    return self
end

-- return a function to cycle this Backplane on a set interval
function Backplane:cycleEvery(seconds)
    local selfCycle = function()
        while true do
            self:cycle()

            t.sleep(seconds)
        end
    end

    -- TODO
    -- this will break support for backplane:cycleEvery(3)() if
    -- async-enabled adapters are attached. docs should be updated
    -- to either remove the direct launching as an option, or
    -- add guidance to all async-enabled adapters to use parallel.
    if #{self.asyncCycleHandlers} > 0 then
        self:dlog('Backplane:cycleEvery :: found async handlers, returning function list')

        return selfCycle, table.unpack(self.asyncCycleHandlers)
    end

    self:dlog('Backplane:cycleEvery :: no async handlers found, returning cycle function')
    return selfCycle
end

-- trigger eager layout updates on all attached outputs with updateLayout functions
function Backplane:updateLayouts()
    self:dlog('Backplane:updateLayouts :: Updating layouts...')

    for _, key in pairs(self.outputKeys) do
        local output = self.outputs[key]

        if type(output.updateLayout) == 'function' then
            self:dlog('Backplane:updateLayouts ::  - ' .. key)

            local results = {pcall(output.updateLayout, output)}

            if not table.remove(results, 1) then
                t.log('Update layout fault for "' .. key .. '":')
                t.pprint(table.remove(results, 1))
            end
        end
    end

    self:dlog('Backplane:updateLayouts :: Layouts updated')
end

function Backplane:debug(debug)
    self.debugState = debug and true or false

    return self
end

function Backplane:dlog(msg)
    if self.debugState then t.log(msg) end
end

return Backplane
end,

["telem.lib.InputAdapter"] = function()
--------------------
-- Module: 'telem.lib.InputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter = o.class()
InputAdapter.type = 'InputAdapter'

function InputAdapter:constructor()
    assert(self.type ~= InputAdapter.type, 'InputAdapter cannot be instantiated')

    self.debugState = false

    self.prefix = ''
    self.asyncCycleHandler = nil

    -- boot components
    self:setBoot(function ()
        self.components = {}
    end)()
end

function InputAdapter:setBoot(proc)
    assert(type(proc) == 'function', 'proc must be a function')

    self.boot = proc

    return self.boot
end

function InputAdapter:setAsyncCycleHandler(proc)
    assert(type(proc) == 'function', 'proc must be a function')
    
    self.asyncCycleHandler = proc

    return self.asyncCycleHandler
end

function InputAdapter:addComponentByPeripheralID (id)
    local tempComponent = peripheral.wrap(id)

    assert(tempComponent, 'Could not find peripheral ID ' .. id)

    self.components[id] = tempComponent
end

function InputAdapter:addComponentByPeripheralType (type)
    local key = type .. '_' .. #{self.components}

    local tempComponent = peripheral.find(type)

    assert(tempComponent, 'Could not find peripheral type ' .. type)

    self.components[key] = tempComponent
end

function InputAdapter:read ()
    self:boot()

    t.err(self.type .. ' has not implemented read()')
end

function InputAdapter:debug(debug)
    self.debugState = debug and true or false

    return self
end

function InputAdapter:dlog(msg)
    if self.debugState then t.log(msg) end
end

return InputAdapter
end,

["telem.lib.Metric"] = function()
--------------------
-- Module: 'telem.lib.Metric'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local Metric = o.class()
Metric.type = 'Metric'

function Metric:constructor (data, data2)
    local datum

    if type(data) == 'table' then
        datum = data
    else
        datum = { name = data, value = data2 }
    end

    assert(type(datum.value) == 'number', 'Metric value must be a number')

    self.name = assert(datum.name, 'Metric must have a name')
    self.value = assert(datum.value, 'Metric must have a value')
    self.unit = datum.unit or nil
    self.source = datum.source or nil
    self.adapter = datum.adapter or nil
end

function Metric:__tostring ()
    local label = self.name .. ' = ' .. self.value

    -- TODO unit source adapter
    local unit, source, adapter

    unit = self.unit and ' ' .. self.unit or ''
    source = self.source and ' (' .. self.source .. ')' or ''
    adapter = self.adapter and ' from ' .. self.adapter or ''

    -- t.pprint(unit)
    -- t.pprint(source)
    -- t.pprint(adapter)

    return label .. unit .. adapter .. source
end

function Metric.pack (self)
    return {
        n = self.name,
        v = self.value,
        u = self.unit,
        s = self.source,
        a = self.adapter,
    }
end

function Metric.unpack (data)
    return Metric({
        name = data.n,
        value = data.v,
        unit = data.u,
        source = data.s,
        adapter = data.a
    })
end

function Metric.serialize (self)
    return textutils.serialize(self:pack(), { compact = true })
end

function Metric.unserialize (data)
    return Metric.unpack(textutils.unserialize(data))
end

return Metric
end,

["telem.lib.MetricCollection"] = function()
--------------------
-- Module: 'telem.lib.MetricCollection'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local Metric = require 'telem.lib.Metric'

local MetricCollection = o.class()
MetricCollection.type = 'MetricCollection'

function MetricCollection:constructor (...)
    self.metrics = {}
    self.context = {}

    local firstArg = select(1, ...)

    if type(firstArg) == 'table' and not o.instanceof(firstArg, Metric) then
        for name, value in pairs(firstArg) do
            self:insert(Metric(name, value))
        end
    else
        for _, v in next, {...} do
            self:insert(v)
        end
    end
end

function MetricCollection:insert (element)
    assert(o.instanceof(element, Metric), 'Element must be a Metric')
    table.insert(self.metrics, element)

    return self
end

function MetricCollection:setContext (ctx)
    self.context = ctx

    return self
end

-- return first metric matching name@adapter
function MetricCollection:find (filter)
    local split = {}

    for sv in (filter .. '@'):gmatch('([^@]*)@') do
        table.insert(split, sv)
    end

    local name = split[1]
    local adapter = split[2]

    local nameish = name ~= nil and #name > 0
    local adapterish = adapter ~= nil and #adapter > 0

    for _,v in pairs(self.metrics) do
        if (not nameish or v.name == name) and (not adapterish or v.adapter == adapter) then
            return v
        end
    end

    return nil
end

function MetricCollection.pack (self)
    local packedMetrics = {}
    local adapterLookup = {}
    local sourceLookup = {}
    local unitLookup = {}
    local nameLookup = {
        -- first name token
        {},

        -- second name token
        {}
    }

    for _,v in ipairs(self.metrics) do
        local packed = v:pack()

        -- create name tokens
        local nameTokens = {}

        for token in (packed.n .. ':'):gmatch('([^:]*):') do
            table.insert(nameTokens, token)
        end

        local t1 = nameTokens[1]
        local t2 = nameTokens[2]
        local t3 = nameTokens[3]

        if #nameTokens > 2 then
            t3 = table.concat(nameTokens, ':', 3)
        end

        local n1, n2, nn

        if t3 then
            n1, n2, nn = t1, t2, t3
        elseif t2 then
            n1, n2, nn = t1, nil, t2
        elseif t1 then
            n1, n2, nn = nil, nil, t1
        end

        -- pull LUT
        local ln1 = n1 and t.indexOf(nameLookup[1], n1)
        local ln2 = n2 and t.indexOf(nameLookup[2], n2)
        local la = t.indexOf(adapterLookup, packed.a)
        local ls = t.indexOf(sourceLookup, packed.s)
        local lu = t.indexOf(unitLookup, packed.u)

        -- register missing LUT
        if ln1 and ln1 < 0 then
            table.insert(nameLookup[1], n1)

            ln1 = #nameLookup[1]
        end
        if ln2 and ln2 < 0 then
            table.insert(nameLookup[2], n2)

            ln2 = #nameLookup[2]
        end
        if la < 0 then
            table.insert(adapterLookup, packed.a)

            la = #adapterLookup
        end
        if ls < 0 then
            table.insert(sourceLookup, packed.s)

            ls = #sourceLookup
        end
        if lu < 0 then
            table.insert(unitLookup, packed.u)

            lu = #unitLookup
        end

        local ln
        if ln1 or ln2 then
            ln = {ln1, ln2}
        end

        table.insert(packedMetrics, {
            ln = ln,
            n = nn,
            v = packed.v,
            la = la,
            ls = ls,
            lu = lu
        })
    end

    return {
        c = self.context,
        ln = nameLookup,
        la = adapterLookup,
        ls = sourceLookup,
        lu = unitLookup,
        m = packedMetrics
    }
end

function MetricCollection.unpack (data)
    local undata = data

    local nameLookup = undata.ln
    local adapterLookup = undata.la
    local sourceLookup = undata.ls
    local unitLookup = undata.lu

    local collection = MetricCollection()

    for _, v in ipairs(undata.m) do
        local nPrefix = ''

        if v.ln then
            for lni, lnv in ipairs(v.ln) do
                nPrefix = nPrefix .. nameLookup[lni][lnv] .. ':'
            end
        end

        local tempMetric = Metric{
            name = nPrefix .. v.n,
            value = v.v,
            adapter = v.la and adapterLookup[v.la],
            source = v.ls and sourceLookup[v.ls],
            unit = v.lu and unitLookup[v.lu]
        }

        collection:insert(tempMetric)
    end

    collection:setContext(undata.c)

    return collection
end

return MetricCollection
end,

["telem.lib.ObjectModel"] = function()
--------------------
-- Module: 'telem.lib.ObjectModel'
--------------------
---@diagnostic disable: deprecated
--
-- Lua object model implementation
--
-- By Shira-3749
-- Source: https://github.com/Shira-3749/lua-object-model
--

local a='Lua 5.1'==_VERSION;local unpack=unpack or table.unpack;local function b(c,...)local d={}setmetatable(d,c)if c.constructor then c.constructor(d,...)end;return d end;local function e(d,f,...)if nil==d.___superScope then d.___superScope={}end;local g=d.___superScope[f]local h;if nil~=g then h=g.__parent else h=d.__parent end;d.___superScope[f]=h;local i={pcall(h[f],d,...)}local j=table.remove(i,1)d.___superScope[f]=g;if not j then error(i[1])end;return unpack(i)end;local function k(d,l)local c=getmetatable(d)while c do if c==l then return true end;c=c.__parent end;return false end;local function m(d)if d.destructor then d:destructor()end end;local function c(n)local c={}if n then for o,p in pairs(n)do c[o]=p end;c.__parent=n end;c.__index=c;if not n and not a then c.__gc=m end;if n then c.super=e end;local q={__call=b}setmetatable(c,q)return c end;return{class=c,instanceof=k,new=b,super=e}
end,

["telem.lib.OutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.OutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local OutputAdapter = o.class()
OutputAdapter.type = 'OutputAdapter'

function OutputAdapter:constructor()
    assert(self.type ~= OutputAdapter.type, 'OutputAdapter cannot be instantiated')

    self.debugState = false

    self.asyncCycleHandler = nil

    -- boot components
    self:setBoot(function ()
        self.components = {}
    end)()
end

function OutputAdapter:setBoot(proc)
    assert(type(proc) == 'function', 'proc must be a function')

    self.boot = proc

    return self.boot
end

function OutputAdapter:setAsyncCycleHandler(proc)
    assert(type(proc) == 'function', 'proc must be a function')
    
    self.asyncCycleHandler = proc

    return self.asyncCycleHandler
end

function OutputAdapter:addComponentByPeripheralID (id)
    local tempComponent = peripheral.wrap(id)

    assert(tempComponent, 'Could not find peripheral ID ' .. id)

    self.components[id] = tempComponent
end

function OutputAdapter:addComponentByPeripheralType (type)
    local key = type .. '_' .. #{self.components}

    local tempComponent = peripheral.find(type)

    assert(tempComponent, 'Could not find peripheral type ' .. type)

    self.components[key] = tempComponent
end

function OutputAdapter:write (metrics)
    t.err(self.type .. ' has not implemented write()')
end

function OutputAdapter:debug(debug)
    self.debugState = debug and true or false

    return self
end

function OutputAdapter:dlog(msg)
    if self.debugState then t.log(msg) end
end

return OutputAdapter
end,

["telem.lib.input"] = function()
--------------------
-- Module: 'telem.lib.input'
--------------------
return {
    helloWorld = require 'telem.lib.input.HelloWorldInputAdapter',
    custom = require 'telem.lib.input.CustomInputAdapter',

    -- storage
    itemStorage = require 'telem.lib.input.ItemStorageInputAdapter',
    fluidStorage = require 'telem.lib.input.FluidStorageInputAdapter',
    refinedStorage = require 'telem.lib.input.RefinedStorageInputAdapter',
    meStorage = require 'telem.lib.input.MEStorageInputAdapter',

    -- machinery
    mekanism = {
        fissionReactor = require 'telem.lib.input.mekanism.FissionReactorInputAdapter',
        inductionMatrix = require 'telem.lib.input.mekanism.InductionMatrixInputAdapter',
        industrialTurbine = require 'telem.lib.input.mekanism.IndustrialTurbineInputAdapter',
        fusionReactor = require 'telem.lib.input.mekanism.FusionReactorInputAdapter',
    },

    -- modem
    secureModem = require 'telem.lib.input.SecureModemInputAdapter'
}
end,

["telem.lib.input.CustomInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.CustomInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local CustomInputAdapter = o.class(InputAdapter)
CustomInputAdapter.type = 'CustomInputAdapter'

function CustomInputAdapter:constructor (func)
    self.readlambda = func

    self:super('constructor')
end

function CustomInputAdapter:read ()
    return MetricCollection(self.readlambda())
end

return CustomInputAdapter
end,

["telem.lib.input.FluidStorageInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.FluidStorageInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local FluidStorageInputAdapter = o.class(InputAdapter)
FluidStorageInputAdapter.type = 'FluidStorageInputAdapter'

function FluidStorageInputAdapter:constructor (peripheralName)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'storage:'

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function FluidStorageInputAdapter:read ()
    self:boot()
    
    local source, fluidStorage = next(self.components)
    local tanks = fluidStorage.tanks()

    local tempMetrics = {}

    for _,v in pairs(tanks) do
        if v then
            local prefixkey = self.prefix .. v.name
            tempMetrics[prefixkey] = (tempMetrics[prefixkey] or 0) + v.amount / 1000
        end
    end

    local metrics = MetricCollection()

    for k,v in pairs(tempMetrics) do
        if v then metrics:insert(Metric({ name = k, value = v, unit = 'B', source = source })) end
    end

    return metrics
end

return FluidStorageInputAdapter
end,

["telem.lib.input.HelloWorldInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.HelloWorldInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local HelloWorldInputAdapter = o.class(InputAdapter)
HelloWorldInputAdapter.type = 'HelloWorldInputAdapter'

function HelloWorldInputAdapter:constructor (checkval)
    self.checkval = checkval

    self:super('constructor')
end

function HelloWorldInputAdapter:read ()
    return MetricCollection{ hello_world = self.checkval }
end

return HelloWorldInputAdapter
end,

["telem.lib.input.ItemStorageInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.ItemStorageInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local ItemStorageInputAdapter = o.class(InputAdapter)
ItemStorageInputAdapter.type = 'ItemStorageInputAdapter'

function ItemStorageInputAdapter:constructor (peripheralName)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'storage:'

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function ItemStorageInputAdapter:read ()
    self:boot()
    
    local source, itemStorage = next(self.components)
    local items = itemStorage.list()

    local tempMetrics = {}

    for _,v in pairs(items) do
        if v then
            local prefixkey = self.prefix .. v.name
            tempMetrics[prefixkey] = (tempMetrics[prefixkey] or 0) + v.count
        end
    end

    local metrics = MetricCollection()

    for k,v in pairs(tempMetrics) do
        if v then metrics:insert(Metric({ name = k, value = v, unit = 'item', source = source })) end
    end

    return metrics
end

return ItemStorageInputAdapter
end,

["telem.lib.input.MEStorageInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.MEStorageInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local MEStorageInputAdapter = o.class(InputAdapter)
MEStorageInputAdapter.type = 'MEStorageInputAdapter'

function MEStorageInputAdapter:constructor (peripheralName)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'storage:'


    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function MEStorageInputAdapter:read ()
    self:boot()
    
    local source, storage = next(self.components)
    local items = storage.listItems()
    local fluids = storage.listFluid()

    local metrics = MetricCollection()

    for _,v in pairs(items) do
        if v then metrics:insert(Metric({ name = self.prefix .. v.name, value = v.amount, unit = 'item', source = source })) end
    end

    for _,v in pairs(fluids) do
        if v then metrics:insert(Metric({ name = self.prefix .. v.name, value = v.amount / 1000, unit = 'B', source = source })) end
    end

    return metrics
end

return MEStorageInputAdapter
end,

["telem.lib.input.RefinedStorageInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.RefinedStorageInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local RefinedStorageInputAdapter = o.class(InputAdapter)
RefinedStorageInputAdapter.type = 'RefinedStorageInputAdapter'

function RefinedStorageInputAdapter:constructor (peripheralName)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'storage:'

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function RefinedStorageInputAdapter:read ()
    self:boot()
    
    local source, storage = next(self.components)
    local items = storage.listItems()
    local fluids = storage.listFluids()

    local metrics = MetricCollection()

    for _,v in pairs(items) do
        if v then metrics:insert(Metric({ name = self.prefix .. v.name, value = v.amount, unit = 'item', source = source })) end
    end

    for _,v in pairs(fluids) do
        if v then metrics:insert(Metric({ name = self.prefix .. v.name, value = v.amount / 1000, unit = 'B', source = source })) end
    end

    return metrics
end

return RefinedStorageInputAdapter
end,

["telem.lib.input.SecureModemInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.SecureModemInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'
local vendor
local ecnet2
local random
local lualzw

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local SecureModemInputAdapter = o.class(InputAdapter)
SecureModemInputAdapter.type = 'SecureModemInputAdapter'

SecureModemInputAdapter.VERSION = 'v2.0.0'

SecureModemInputAdapter.REQUEST_PREAMBLE = 'telem://'
SecureModemInputAdapter.REQUESTS = {
    GET_COLLECTION = SecureModemInputAdapter.REQUEST_PREAMBLE .. SecureModemInputAdapter.VERSION .. '/collection',
}

function SecureModemInputAdapter:constructor (peripheralName, address)
    self:super('constructor')

    self.inputAddress = address
    self.protocol = nil
    self.connection = nil

    self.receiveTimeout = 1

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)

        if not vendor then
            self:dlog('SecureModemInput:boot :: Loading vendor modules...')

            vendor = require 'telem.vendor'

            self:dlog('SecureModemInput:boot :: Vendor modules ready.')
        end

        if not random then
            self:dlog('SecureModemInput:boot :: Loading ccryptolib.random...')

            random = vendor.ccryptolib.random

            self:dlog('SecureModemInput:boot :: ccryptolib.random ready.')
        end

        -- lazy load because it is slow
        if not ecnet2 then
            self:dlog('SecureModemInput:boot :: Loading ECNet2...')

            ecnet2 = vendor.ecnet2

            -- TODO fallback initializer when http not available
            local postHandle = assert(http.post("https://krist.dev/ws/start", "{}"))
            local data = textutils.unserializeJSON(postHandle.readAll())
            postHandle.close()
            random.init(data.url)
            http.websocket(data.url).close()
            
            self:dlog('SecureModemInput:boot :: ECNet2 ready. Address = ' .. ecnet2.address())
        end

        if not lualzw then
            self:dlog('SecureModemInput:boot :: Loading lualzw...')

            lualzw = vendor.lualzw

            self:dlog('SecureModemInput:boot :: lualzw ready.')
        end

        self:dlog('SecureModemInput:boot :: Opening modem...')

        ecnet2.open(peripheralName)

        self:dlog('SecureModemInput:boot :: Initializing protocol...')

        self.protocol = ecnet2.Protocol {
            name = "telem",
            serialize = textutils.serialize,
            deserialize = textutils.unserialize,
        }

        self:dlog('SecureModemInput:boot :: Boot complete.')
    end)()
end

function SecureModemInputAdapter:read ()
    local _, modem = next(self.components)
    local peripheralName = getmetatable(modem).name

    local connect = function ()
        self:dlog('SecureModemInput:read :: connecting to ' .. self.inputAddress)

        -- TODO come up with better catch mekanism here
        self.connection = self.protocol:connect(self.inputAddress, peripheralName)

        local ack = select(2, self.connection:receive(3))

        if ack then
            self:dlog('SecureModemInput:read :: remote ack: ' .. ack)

            -- TODO this is dumb way, make good way
            if ack ~= 'telem ' .. self.VERSION then
                t.log('SecureModemInput:read :: protocol mismatch: telem ' .. self.VERSION .. ' => ' .. ack)
                return false
            end

            self:dlog('SecureModemInput:read :: connection established')
            return true
        end

        t.log('SecureModemInput:read :: ECNet2 connection failed. Please verify remote server is running.')

        self.connection = nil

        return false
    end

    self:dlog('SecureModemInput:read :: connected? ' .. tostring(self.connection))

    if not self.connection and not connect() then
        return MetricCollection()
    end
    
    self:dlog('SecureModemInput:read :: sending request to ' .. self.inputAddress)

    local sendResult, errorResult = pcall(self.connection.send, self.connection, self.REQUESTS.GET_COLLECTION)

    if not sendResult then
        self:dlog('SecureModemInput:read :: Connection stale, retrying next cycle')
        self.connection = nil
        return MetricCollection()
    end

    self:dlog('SecureModemInput:read :: listening for response')
    local sender, message = self.connection:receive(self.receiveTimeout)

    if not sender then
        t.log('SecureModemInput:read :: Receive timed out after ' .. self.receiveTimeout .. ' seconds, retrying next cycle')

        self.connection = nil

        return MetricCollection()
    end

    local unwrapped = message
    
    -- decompress if needed
    if type(message) == 'string' and string.sub(message, 1, 1) == 'c' then
        unwrapped = textutils.unserialize(lualzw.decompress(message))
    end

    local unpacked = MetricCollection.unpack(unwrapped)

    self:dlog('SecureModemInput:read :: response received')

    return unpacked
end

return SecureModemInputAdapter
end,

["telem.lib.input.mekanism.FissionReactorInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.mekanism.FissionReactorInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local FissionReactorInputAdapter = o.class(InputAdapter)
FissionReactorInputAdapter.type = 'FissionReactorInputAdapter'

function FissionReactorInputAdapter:constructor (peripheralName, categories)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'mekfission:'

    -- TODO make these constants
    local allCategories = {
        'basic',
        'advanced',
        'fuel',
        'coolant',
        'waste',
        'formation'
    }

    if not categories then
        self.categories = { 'basic' }
    elseif categories == '*' then
        self.categories = allCategories
    else
        self.categories = categories
    end

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function FissionReactorInputAdapter:read ()
    self:boot()
    
    local source, fission = next(self.components)

    local metrics = MetricCollection()

    local loaded = {}

    for _,v in ipairs(self.categories) do
        -- skip, already loaded
        if loaded[v] then
            -- do nothing

        -- minimum necessary for monitoring a fission reactor safely
        elseif v == 'basic' then
            metrics:insert(Metric{ name = self.prefix .. 'status', value = (fission.getStatus() and 1 or 0), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'burn_rate', value = fission.getBurnRate() / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_burn_rate', value = fission.getMaxBurnRate() / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'temperature', value = fission.getTemperature(), unit = 'K', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'damage_percent', value = fission.getDamagePercent(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'fuel_filled_percentage', value = fission.getFuelFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'coolant_filled_percentage', value = fission.getCoolantFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'heated_coolant_filled_percentage', value = fission.getHeatedCoolantFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'waste_filled_percentage', value = fission.getWasteFilledPercentage(), unit = nil, source = source })

        -- some further production metrics
        elseif v == 'advanced' then
            metrics:insert(Metric{ name = self.prefix .. 'actual_burn_rate', value = fission.getActualBurnRate() / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'environmental_loss', value = fission.getEnvironmentalLoss(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'heating_rate', value = fission.getHeatingRate() / 1000, unit = 'B/t', source = source })

        elseif v == 'coolant' then
            metrics:insert(Metric{ name = self.prefix .. 'coolant', value = fission.getCoolant().amount / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'coolant_capacity', value = fission.getCoolantCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'coolant_needed', value = fission.getCoolantNeeded() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'heated_coolant', value = fission.getHeatedCoolant().amount / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'heated_coolant_capacity', value = fission.getHeatedCoolantCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'heated_coolant_needed', value = fission.getHeatedCoolantNeeded() / 1000, unit = 'B', source = source })

        elseif v == 'fuel' then
            metrics:insert(Metric{ name = self.prefix .. 'fuel', value = fission.getFuel().amount / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'fuel_capacity', value = fission.getFuelCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'fuel_needed', value = fission.getFuelNeeded(), unit = 'B', source = source })

        elseif v == 'waste' then
            metrics:insert(Metric{ name = self.prefix .. 'waste', value = fission.getWaste().amount / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'waste_capacity', value = fission.getWasteCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'waste_needed', value = fission.getWasteNeeded() / 1000, unit = 'B', source = source })

        -- measurements based on the multiblock structure itself
        elseif v == 'formation' then
            metrics:insert(Metric{ name = self.prefix .. 'formed', value = (fission.isFormed() and 1 or 0), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'force_disabled', value = (fission.isForceDisabled() and 1 or 0), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'height', value = fission.getHeight(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'length', value = fission.getLength(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'width', value = fission.getWidth(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'fuel_assemblies', value = fission.getFuelAssemblies(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'fuel_surface_area', value = fission.getFuelSurfaceArea(), unit = 'm²', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'heat_capacity', value = fission.getHeatCapacity(), unit = 'J/K', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'boil_efficiency',  value = fission.getBoilEfficiency(), unit = nil, source = source })
        end

        loaded[v] = true

        -- not sure if these are useful, but they return strings anyway which are not Metric compatible, RIP
        -- metrics:insert(Metric{ name = self.prefix .. 'logic_mode', value = fission.getLogicMode(), unit = nil, source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'redstone_logic_status', value = fission.getRedstoneLogicStatus(), unit = nil, source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'redstone_mode', value = fission.getRedstoneLogicStatus(), unit = nil, source = source })
    end

    return metrics
end

return FissionReactorInputAdapter
end,

["telem.lib.input.mekanism.FusionReactorInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.mekanism.FusionReactorInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local FusionReactorInputAdapter = o.class(InputAdapter)
FusionReactorInputAdapter.type = 'FusionReactorInputAdapter'

function FusionReactorInputAdapter:constructor (peripheralName, categories)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'mekfusion:'

    -- TODO make these constants
    local allCategories = {
        'basic',
        'advanced',
        'fuel',
        'coolant',
        'formation'
    }

    if not categories then
        self.categories = { 'basic' }
    elseif categories == '*' then
        self.categories = allCategories
    else
        self.categories = categories
    end

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function FusionReactorInputAdapter:read ()
    self:boot()

    local source, fusion = next(self.components)

    local metrics = MetricCollection()

    local loaded = {}

    for _,v in ipairs(self.categories) do
        -- skip, already loaded
        if loaded[v] then
            -- do nothing

        -- minimum necessary for monitoring a fusion reactor
        elseif v == 'basic' then
            local isActive = fusion.isActiveCooledLogic()
            metrics:insert(Metric{ name = self.prefix .. 'plasma_temperature', value = fusion.getPlasmaTemperature(), unit = 'K', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'case_temperature', value = fusion.getCaseTemperature(), unit = 'K', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'water_filled_percentage', value = fusion.getWaterFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam_filled_percentage', value = fusion.getSteamFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'tritium_filled_percentage', value = fusion.getTritiumFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'deuterium_filled_percentage', value = fusion.getDeuteriumFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'dt_fuel_filled_percentage', value = fusion.getDTFuelFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'production_rate', value = mekanismEnergyHelper.joulesToFE(fusion.getProductionRate()), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'injection_rate', value = fusion.getInjectionRate() / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'min_injection_rate', value = fusion.getMinInjectionRate(isActive) / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_plasma_temperature', value = fusion.getMaxPlasmaTemperature(isActive), unit = 'K', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_casing_temperature', value = fusion.getMaxCasingTemperature(isActive), unit = 'K', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'passive_generation_rate', value = mekanismEnergyHelper.joulesToFE(fusion.getPassiveGeneration(isActive)), unit = 'FE/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'ignition_temperature', value = fusion.getIgnitionTemperature(isActive), unit = 'K', source = source })

        -- some further production metrics
        elseif v == 'advanced' then
            -- metrics:insert(Metric{ name = self.prefix .. 'transfer_loss', value = fusion.getTransferLoss(), unit = nil, source = source })
            -- metrics:insert(Metric{ name = self.prefix .. 'environmental_loss', value = fusion.getEnvironmentalLoss(), unit = nil, source = source })
            
        elseif v == 'coolant' then
            metrics:insert(Metric{ name = self.prefix .. 'water_capacity', value = fusion.getWaterCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'water_needed', value = fusion.getWaterNeeded() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam_capacity', value = fusion.getSteamCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam_needed', value = fusion.getSteamNeeded() / 1000, unit = 'B', source = source })
            
        elseif v == 'fuel' then
            metrics:insert(Metric{ name = self.prefix .. 'tritium_capacity', value = fusion.getTritiumCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'tritium_needed', value = fusion.getTritiumNeeded() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'deuterium_capacity', value = fusion.getDeuteriumCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'deuterium_needed', value = fusion.getDeuteriumNeeded() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'dt_fuel_capacity', value = fusion.getDTFuelCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'dt_fuel_needed', value = fusion.getDTFuelNeeded() / 1000, unit = 'B', source = source })
            
            -- measurements based on the multiblock structure itself
        elseif v == 'formation' then
            metrics:insert(Metric{ name = self.prefix .. 'formed', value = (fusion.isFormed() and 1 or 0), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'height', value = fusion.getHeight(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'length', value = fusion.getLength(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'width', value = fusion.getWidth(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'active_cooled_logic', value = (fusion.isActiveCooledLogic() and 1 or 0), unit = nil, source = source })
        end
        
        loaded[v] = true
        
        -- not sure if these are useful, but they return strings anyway which are not Metric compatible, RIP
        -- metrics:insert(Metric{ name = self.prefix .. 'logic_mode', value = fusion.getLogicMode(), unit = nil, source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'tritium', value = fusion.getTritium() / 1000, unit = 'B', source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'deuterium', value = fusion.getDeuterium() / 1000, unit = 'B', source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'dt_fuel', value = fusion.getDTFuel() / 1000, unit = 'B', source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'hohlraum', value = fusion.getHohlraum(), unit = nil, source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'water', value = fusion.getWater() / 1000, unit = 'B', source = source })
        -- metrics:insert(Metric{ name = self.prefix .. 'steam', value = fusion.getSteam() / 1000, unit = 'B', source = source })
    end
    
    return metrics
end

return FusionReactorInputAdapter
end,

["telem.lib.input.mekanism.InductionMatrixInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.mekanism.InductionMatrixInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local InductionMatrixInputAdapter = o.class(InputAdapter)
InductionMatrixInputAdapter.type = 'InductionMatrixInputAdapter'

function InductionMatrixInputAdapter:constructor (peripheralName, categories)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'mekinduction:'

    local allCategories = {
        'basic',
        'advanced',
        'energy',
        'formation'
    }

    if not categories then
        self.categories = { 'basic' }
    elseif categories == '*' then
        self.categories = allCategories
    else
        self.categories = categories
    end

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function InductionMatrixInputAdapter:read ()
    self:boot()
    
    local source, induction = next(self.components)

    local metrics = MetricCollection()

    local loaded = {}

    for _,v in ipairs(self.categories) do
        -- skip, already loaded
        if loaded[v] then
            -- do nothing

        -- minimum necessary for monitoring a fission reactor safely
        elseif v == 'basic' then
            metrics:insert(Metric{ name = self.prefix .. 'energy_filled_percentage', value = induction.getEnergyFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_input', value = mekanismEnergyHelper.joulesToFE(induction.getLastInput()), unit = 'FE/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_output', value = mekanismEnergyHelper.joulesToFE(induction.getLastOutput()), unit = 'FE/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_transfer_cap', value = mekanismEnergyHelper.joulesToFE(induction.getTransferCap()), unit = 'FE/t', source = source })

        -- some further production metrics
        elseif v == 'advanced' then
            metrics:insert(Metric{ name = self.prefix .. 'comparator_level', value = induction.getComparatorLevel(), unit = nil, source = source })

        elseif v == 'energy' then
            metrics:insert(Metric{ name = self.prefix .. 'energy', value = mekanismEnergyHelper.joulesToFE(induction.getEnergy()), unit = 'FE', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_energy', value = mekanismEnergyHelper.joulesToFE(induction.getMaxEnergy()), unit = 'FE', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_needed', value = mekanismEnergyHelper.joulesToFE(induction.getEnergyNeeded()), unit = 'FE', source = source })

        -- measurements based on the multiblock structure itself
        elseif v == 'formation' then
            metrics:insert(Metric{ name = self.prefix .. 'formed', value = (induction.isFormed() and 1 or 0), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'height', value = induction.getHeight(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'length', value = induction.getLength(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'width', value = induction.getWidth(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'installed_cells', value = induction.getInstalledCells(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'installed_providers', value = induction.getInstalledProviders(), unit = nil, source = source })
        end

        loaded[v] = true

        -- not sure if these are useful, but they return types which are not Metric compatible, RIP
        -- induction.getInputItem()
        -- induction.getOutputItem()
        -- induction.getMaxPos()
        -- induction.getMinPos()
    end

    return metrics
end

return InductionMatrixInputAdapter
end,

["telem.lib.input.mekanism.IndustrialTurbineInputAdapter"] = function()
--------------------
-- Module: 'telem.lib.input.mekanism.IndustrialTurbineInputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local InputAdapter      = require 'telem.lib.InputAdapter'
local Metric            = require 'telem.lib.Metric'
local MetricCollection  = require 'telem.lib.MetricCollection'

local IndustrialTurbineInputAdapter = o.class(InputAdapter)
IndustrialTurbineInputAdapter.type = 'IndustrialTurbineInputAdapter'

local DUMPING_MODES = {
    IDLE = 1,
    DUMPING_EXCESS = 2,
    DUMPING = 3,
}

function IndustrialTurbineInputAdapter:constructor (peripheralName, categories)
    self:super('constructor')

    -- TODO this will be a configurable feature later
    self.prefix = 'mekturbine:'

    local allCategories = {
        'basic',
        'advanced',
        'energy',
        'steam',
        'formation'
    }

    if not categories then
        self.categories = { 'basic' }
    elseif categories == '*' then
        self.categories = allCategories
    else
        self.categories = categories
    end

    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)
    end)()
end

function IndustrialTurbineInputAdapter:read ()
    self:boot()
    
    local source, turbine = next(self.components)

    local metrics = MetricCollection()

    local loaded = {}

    for _,v in ipairs(self.categories) do
        -- skip, already loaded
        if loaded[v] then
            -- do nothing

        -- minimum necessary for monitoring a fission reactor safely
        elseif v == 'basic' then
            metrics:insert(Metric{ name = self.prefix .. 'energy_filled_percentage', value = turbine.getEnergyFilledPercentage(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_production_rate', value = mekanismEnergyHelper.joulesToFE(turbine.getProductionRate()), unit = 'FE/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_max_production', value = mekanismEnergyHelper.joulesToFE(turbine.getMaxProduction()), unit = 'FE/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam_filled_percentage', value = turbine.getSteamFilledPercentage(), unit = nil, source = source })

        -- some further production metrics
        elseif v == 'advanced' then
            metrics:insert(Metric{ name = self.prefix .. 'comparator_level', value = turbine.getComparatorLevel(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'dumping_mode', value = DUMPING_MODES[turbine.getDumpingMode()], unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'flow_rate', value = turbine.getFlowRate() / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_flow_rate', value = turbine.getMaxFlowRate() / 1000, unit = 'B/t', source = source })

        elseif v == 'energy' then
            metrics:insert(Metric{ name = self.prefix .. 'energy', value = mekanismEnergyHelper.joulesToFE(turbine.getEnergy()), unit = 'FE', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_energy', value = mekanismEnergyHelper.joulesToFE(turbine.getMaxEnergy()), unit = 'FE', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'energy_needed', value = mekanismEnergyHelper.joulesToFE(turbine.getEnergyNeeded()), unit = 'FE', source = source })

        elseif v == 'steam' then
            metrics:insert(Metric{ name = self.prefix .. 'steam_input_rate', value = turbine.getLastSteamInputRate() / 1000, unit = 'B/t', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam', value = turbine.getSteam().amount / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam_capacity', value = turbine.getSteamCapacity() / 1000, unit = 'B', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'steam_needed', value = turbine.getSteamNeeded() / 1000, unit = 'B', source = source })

        -- measurements based on the multiblock structure itself
        elseif v == 'formation' then
            metrics:insert(Metric{ name = self.prefix .. 'formed', value = (turbine.isFormed() and 1 or 0), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'height', value = turbine.getHeight(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'length', value = turbine.getLength(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'width', value = turbine.getWidth(), unit = 'm', source = source })
            metrics:insert(Metric{ name = self.prefix .. 'blades', value = turbine.getBlades(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'coils', value = turbine.getCoils(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'condensers', value = turbine.getCondensers(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'dispersers', value = turbine.getDispersers(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'vents', value = turbine.getVents(), unit = nil, source = source })
            metrics:insert(Metric{ name = self.prefix .. 'max_water_output', value = turbine.getMaxWaterOutput() / 1000, unit = 'B/t', source = source })
        end

        loaded[v] = true

        -- not sure if these are useful, but they return types which are not Metric compatible, RIP
        -- turbine.getMaxPos(),
        -- turbine.getMinPos(),
    end

    return metrics
end

return IndustrialTurbineInputAdapter
end,

["telem.lib.output"] = function()
--------------------
-- Module: 'telem.lib.output'
--------------------
return {
    helloWorld = require 'telem.lib.output.HelloWorldOutputAdapter',
    custom = require 'telem.lib.output.CustomOutputAdapter',

    -- HTTP
    grafana = require 'telem.lib.output.GrafanaOutputAdapter',

    -- Basalt
    basalt = {
        label = require 'telem.lib.output.basalt.LabelOutputAdapter',
        graph = require 'telem.lib.output.basalt.GraphOutputAdapter',
    },

    -- Plotter
    plotter = {
        line = require 'telem.lib.output.plotter.ChartLineOutputAdapter',
    },

    -- Modem
    secureModem = require 'telem.lib.output.SecureModemOutputAdapter'
}
end,

["telem.lib.output.CustomOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.CustomOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local CustomOutputAdapter = o.class(OutputAdapter)
CustomOutputAdapter.type = 'CustomOutputAdapter'

function CustomOutputAdapter:constructor (func)
    self.writelambda = func

    self:super('constructor')
end

function CustomOutputAdapter:write (collection)
    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    self.writelambda(collection)
end

return CustomOutputAdapter
end,

["telem.lib.output.GrafanaOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.GrafanaOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local GrafanaOutputAdapter = o.class(OutputAdapter)
GrafanaOutputAdapter.type = 'GrafanaOutputAdapter'

function GrafanaOutputAdapter:constructor (endpoint, apiKey)
    self:super('constructor')

    self.endpoint = assert(endpoint, 'Endpoint is required')
    self.apiKey = assert(apiKey, 'API key is required')
end

function GrafanaOutputAdapter:write (collection)
    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    local outf = {}

    for _,v in pairs(collection.metrics) do
        local unitreal = (v.unit and v.unit ~= '' and ',unit=' .. v.unit) or ''
        local sourcereal = (v.source and v.source ~= '' and ',source=' .. v.source) or ''
        local adapterreal = (v.adapter and v.adapter ~= '' and ',adapter=' .. v.adapter) or ''

        table.insert(outf, v.name .. unitreal .. sourcereal .. adapterreal .. (' metric=%f'):format(v.value))
    end

    -- t.pprint(collection)

    local res = http.post({
        url = self.endpoint,
        body = table.concat(outf, '\n'),
        headers = { Authorization = ('Bearer %s'):format(self.apiKey) }
    })
end

return GrafanaOutputAdapter
end,

["telem.lib.output.HelloWorldOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.HelloWorldOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local HelloWorldOutputAdapter = o.class(OutputAdapter)
HelloWorldOutputAdapter.type = 'HelloWorldOutputAdapter'

function HelloWorldOutputAdapter:constructor ()
    self:super('constructor')
end

function HelloWorldOutputAdapter:write (collection)
    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    for k,v in pairs(collection.metrics) do
        print('Hello, ' .. v.name .. ' = ' .. v.value .. '!')
    end
end

return HelloWorldOutputAdapter
end,

["telem.lib.output.SecureModemOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.SecureModemOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'
local vendor
local ecnet2
local random
local lualzw

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local SecureModemOutputAdapter = o.class(OutputAdapter)
SecureModemOutputAdapter.type = 'SecureModemOutputAdapter'

SecureModemOutputAdapter.VERSION = 'v2.0.0'

SecureModemOutputAdapter.REQUEST_PREAMBLE = 'telem://'
SecureModemOutputAdapter.REQUESTS = {
    GET_COLLECTION = SecureModemOutputAdapter.REQUEST_PREAMBLE .. SecureModemOutputAdapter.VERSION .. '/collection',
}

function SecureModemOutputAdapter:constructor (peripheralName)
    self:super('constructor')

    self.protocol = nil
    self.connections = {}

    -- TODO test modem disconnect recovery
    -- boot components
    self:setBoot(function ()
        self.components = {}

        self:addComponentByPeripheralID(peripheralName)

        if not vendor then
            self:dlog('SecureModemOutput:boot :: Loading vendor modules...')

            vendor = require 'telem.vendor'

            self:dlog('SecureModemOutput:boot :: Vendor modules ready.')
        end

        if not random then
            self:dlog('SecureModemOutput:boot :: Loading ccryptolib.random...')

            random = vendor.ccryptolib.random

            self:dlog('SecureModemOutput:boot :: ccryptolib.random ready.')
        end

        -- lazy load because it is slow
        if not ecnet2 then
            t.log('SecureModemOutput:boot :: Loading ECNet2...')

            ecnet2 = vendor.ecnet2

            -- TODO fallback initializer when http not available
            local postHandle = assert(http.post("https://krist.dev/ws/start", "{}"))
            local data = textutils.unserializeJSON(postHandle.readAll())
            postHandle.close()
            random.init(data.url)
            http.websocket(data.url).close()
            
            t.log('SecureModemOutput:boot :: ECNet2 ready. Address = ' .. ecnet2.address())
        end

        if not lualzw then
            self:dlog('SecureModemOutput:boot :: Loading lualzw...')

            lualzw = vendor.lualzw

            self:dlog('SecureModemOutput:boot :: lualzw ready.')
        end

        self:dlog('SecureModemOutput:boot :: Opening modem...')

        ecnet2.open(peripheralName)

        if not self.protocol then
            self:dlog('SecureModemOutput:boot :: Initializing protocol...')

            self.protocol = ecnet2.Protocol {
                name = "telem",
                serialize = textutils.serialize,
                deserialize = textutils.unserialize,
            }
        end

        self:dlog('SecureModemOutput:boot :: Boot complete.')
    end)()

    -- register async adapter
    self:setAsyncCycleHandler(function (backplane)
        local listener = self.protocol:listen()

        self:dlog('SecureModemOutput:asyncCycleHandler :: Listener started')

        while true do
            local event, id, p2, p3 = os.pullEvent()

            if event == "ecnet2_request" and id == listener.id then
                self:dlog('SecureModemOutput:asyncCycleHandler :: received connection from ' .. id)

                self:dlog('SecureModemOutput:asyncCycleHandler :: sending ack...')

                local connection = listener:accept('telem ' .. self.VERSION, p2)

                self.connections[connection.id] = connection

                self:dlog('SecureModemOutput:asyncCycleHandler :: ack sent, connection ' .. connection.id .. ' cached')
            elseif event == "ecnet2_message" and self.connections[id] then
                self:dlog('SecureModemOutput:asyncCycleHandler :: received request from ' .. p2)

                if p3 == self.REQUESTS.GET_COLLECTION then
                    self:dlog('SecureModemOutput:asyncCycleHandler :: request = GET_COLLECTION')

                    local payload = backplane.collection:pack()

                    -- use compression for payloads with > 256 metrics
                    if #payload.m > 256 then
                        self:dlog('SecureModemOutput:asyncCycleHandler :: compressing large payload...')

                        payload = lualzw.compress(textutils.serialize(payload, { compact = true }))
                    end

                    self.connections[id]:send(payload)

                    self:dlog('SecureModemOutput:asyncCycleHandler :: response sent')
                else
                    t.log('SecureModemOutput: Unknown request: ' .. tostring(p3))
                end
            end
        end
    end)
end

function SecureModemOutputAdapter:write (collection)
    self:boot()

    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    -- no op, all async :)
end

return SecureModemOutputAdapter
end,

["telem.lib.output.basalt.GraphOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.basalt.GraphOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local GraphOutputAdapter = o.class(OutputAdapter)
GraphOutputAdapter.type = 'GraphOutputAdapter'

GraphOutputAdapter.MAX_ENTRIES = 50
GraphOutputAdapter.SCALE_TICK = 10

local function graphtrackrange (self)
    local min = self.graphdata[1]
    local max = self.graphdata[1]

    for k,v in ipairs(self.graphdata) do
        if v < min then min = v end
        if v > max then max = v end
    end

    return min,max
end

function GraphOutputAdapter:constructor (frame, filter, bg, fg)
    self:super('constructor')

    self.bBaseFrame = assert(frame, 'Frame is required')
    self.filter = assert(filter, 'Filter is required')
    
    self.graphdata = {}

    self:register(bg, fg)
end

function GraphOutputAdapter:register (bg, fg)
    local currentmin = 0
    local currentmax = 1000

    self.tick = 0

    self.bInnerFrame = self.bBaseFrame:addFrame()
        :setBackground(bg)
        :setSize('{parent.w}', '{parent.h}')

    local fGraph = self.bInnerFrame:addFrame('fGraph'):setBackground(bg)
        :setPosition(1,1)
        :setSize('{parent.w - 2}', '{parent.h - 6}')

    local fLabel = self.bInnerFrame:addFrame('fLabel'):setBackground(bg)
        :setSize('{parent.w - 2}', 4)
        :setPosition(1,'{parent.h - 5}')

    local fLabelMax = self.bInnerFrame:addFrame('fLabelMax'):setBackground(bg)
        :setSize(6, 1)
        :setPosition('{parent.w - 7}',1)

    local fLabelMin = self.bInnerFrame:addFrame('fLabelMin'):setBackground(bg)
        :setSize(6, 1)
        :setPosition('{parent.w - 7}','{fLabel.y - 2}')

    self.label = fLabel:addLabel()
        :setText("-----")
        :setPosition('{parent.w/2-self.w/2}', 2)
        :setForeground(fg)
        :setBackground(bg)

    self.graph = fGraph:addGraph()
        :setPosition(1,1)
        :setSize('{parent.w - 1}', '{parent.h - 1}')
        :setMaxEntries(self.MAX_ENTRIES)
        :setBackground(bg)
        :setGraphColor(fg)
        :setGraphSymbol(' ')
    
    self.graphscale = fGraph:addGraph()
        :setGraphType('scatter')
        :setPosition(1,'{parent.h - 1}')
        :setSize('{parent.w - 1}', 2)
        :setMaxEntries(self.MAX_ENTRIES)
        :setBackground(colors.transparent)
        :setGraphSymbol('|')

    self.labelmax = fLabelMax:addLabel()
        :setPosition(1,1)
        :setText('-----')
        :setForeground(fg)
        :setBackground(bg)
    
    self.labelmin = fLabelMin:addLabel()
        :setPosition(1,1)
        :setText('-----')
        :setForeground(fg)
        :setBackground(bg)

    self.graph:setMinValue(currentmin):setMaxValue(currentmax)
end

function GraphOutputAdapter:write (collection)
    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    local resultMetric = collection:find(self.filter)

    assert(resultMetric, 'could not find metric')

    t.constrainAppend(self.graphdata, resultMetric.value, self.MAX_ENTRIES)

    local newmin, newmax = graphtrackrange(self)

    self.graph:setMinValue(newmin):setMaxValue(newmax)

    self.graph:addDataPoint(resultMetric.value)

    self.label:setFontSize(2)
    self.label:setText(t.shortnum(resultMetric.value))

    if self.tick == self.SCALE_TICK then
        self.graphscale:addDataPoint(100)
        self.tick = 1
    else
        self.graphscale:addDataPoint(50)
        self.tick = self.tick + 1
    end

    self.labelmax:setText(t.shortnum(newmax))
    self.labelmin:setText(t.shortnum(newmin))
    
    return self
end

return GraphOutputAdapter
end,

["telem.lib.output.basalt.LabelOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.basalt.LabelOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local LabelOutputAdapter = o.class(OutputAdapter)
LabelOutputAdapter.type = 'LabelOutputAdapter'

function LabelOutputAdapter:constructor (frame, filter, bg, fg, fontSize)
    self:super('constructor')

    self.bBaseFrame = assert(frame, 'Frame is required')
    self.filter = assert(filter, 'Filter is required')
    self.nameScroll = 1
    self.nameText = '-----'

    self:register(bg, fg, fontSize)
end

function LabelOutputAdapter:register (bg, fg, fontSize)
    self.bInnerFrame = self.bBaseFrame

    -- TODO idk if this inner frame is necessary
    self.bInnerFrame = self.bBaseFrame:addFrame()
        :setBackground(bg)
        :setSize('{parent.w}', '{parent.h}')

    self.bLabelValue = self.bInnerFrame
        :addLabel()
        :setText("-----")
        :setFontSize(fontSize or 2)
        :setBackground(bg)
        :setForeground(fg)
        :setPosition('{parent.w/2-self.w/2}', '{parent.h/2-self.h/2}')
    
    self.bLabelName = self.bInnerFrame
        :addLabel()
        :setText(self.nameText)
        :setBackground(bg)
        :setForeground(fg)
        :setPosition(1,1)
    
    self.animThread = self.bInnerFrame:addThread()
        :start(function ()
            while true do
                local goslep = 0.2
                self.nameScroll = self.nameScroll + 1
                if self.nameScroll > self.nameText:len() + 3 then
                    self.nameScroll = 0
                    goslep = 3
                end
                self:refreshLabels()
                t.sleep(goslep)
            end
        end)
end

function LabelOutputAdapter:refreshLabels ()
    local width = self.bBaseFrame:getWidth()
    local newtext = '-----'
    
    if self.nameText:len() > width then
        newtext = (self.nameText .. ' ' .. string.char(183) .. ' ' .. self.nameText):sub(self.nameScroll)
    else
        newtext = self.nameText
    end

    self.bLabelName:setText(newtext)
end

function LabelOutputAdapter:write (collection)
    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    local resultMetric = collection:find(self.filter)

    assert(resultMetric, 'could not find metric')

    self.bLabelValue:setText(t.shortnum(resultMetric.value))
    self.nameText = resultMetric.name
    self:refreshLabels()

    return self
end

return LabelOutputAdapter
end,

["telem.lib.output.plotter.ChartLineOutputAdapter"] = function()
--------------------
-- Module: 'telem.lib.output.plotter.ChartLineOutputAdapter'
--------------------
local o = require 'telem.lib.ObjectModel'
local t = require 'telem.lib.util'
local vendor
local plotterFactory

local OutputAdapter     = require 'telem.lib.OutputAdapter'
local MetricCollection  = require 'telem.lib.MetricCollection'

local ChartLineOutputAdapter = o.class(OutputAdapter)
ChartLineOutputAdapter.type = 'ChartLineOutputAdapter'

ChartLineOutputAdapter.MAX_ENTRIES = 50
ChartLineOutputAdapter.X_TICK = 10

function ChartLineOutputAdapter:constructor (win, filter, bg, fg)
    self:super('constructor')

    self.win = assert(win, 'Window is required')
    self.filter = assert(filter, 'Filter is required')

    self.plotter = nil
    self.plotData = {}
    self.gridOffsetX = 0

    self.filter = filter

    self.bg = bg or win.getBackgroundColor() or colors.black
    self.fg = fg or win.getTextColor() or colors.white

    self:register()
end

function ChartLineOutputAdapter:register ()
    if not vendor then
        self:dlog('ChartLineOutputAdapter:boot :: Loading vendor modules...')

        vendor = require 'telem.vendor'

        self:dlog('ChartLineOutputAdapter:boot :: Vendor modules ready.')
    end

    if not plotterFactory then
        self:dlog('ChartLineOutputAdapter:boot :: Loading plotter...')

        plotterFactory = vendor.plotter

        self:dlog('ChartLineOutputAdapter:boot :: plotter ready.')
    end

    self:updateLayout()

    for i = 1, self.MAX_ENTRIES do
        t.constrainAppend(self.plotData, self.plotter.NAN, self.MAX_ENTRIES)
    end
end

function ChartLineOutputAdapter:updateLayout (bypassRender)
    self.plotter = plotterFactory(self.win)

    if not bypassRender then
        self:render()
    end
end

function ChartLineOutputAdapter:write (collection)
    assert(o.instanceof(collection, MetricCollection), 'Collection must be a MetricCollection')

    local resultMetric = collection:find(self.filter)

    assert(resultMetric, 'could not find metric')

    -- TODO data width setting
    self.gridOffsetX = self.gridOffsetX - t.constrainAppend(self.plotData, resultMetric and resultMetric.value or self.plotter.NAN, self.MAX_ENTRIES)

    -- TODO X_TICK setting
    if self.gridOffsetX % self.X_TICK == 0 then
        self.gridOffsetX = 0
    end

    -- lazy layout update
    local winw, winh = self.win.getSize()
    if winw ~= self.plotter.box.term_width or winh ~= self.plotter.box.term_height then
        self:updateLayout(true)
    end

    self:render()
    
    return self
end

function ChartLineOutputAdapter:render ()
    local dataw = #{self.plotData}

    local actualmin, actualmax = math.huge, -math.huge

    for _, v in ipairs(self.plotData) do
        -- skip NAN
        if v ~= self.plotter.NAN then
            if v < actualmin then actualmin = v end
            if v > actualmax then actualmax = v end
        end
    end
    
    local flatlabel = nil

    -- NaN data
    if actualmin == math.huge then
        flatlabel = 'NaN'

        actualmin, actualmax = 0, 0
    end

    -- flat data
    if actualmin == actualmax then
        local minrange = 0.000001

        if not flatlabel then
            flatlabel = t.shortnum2(actualmin)
        end

        actualmin = actualmin - minrange / 2
        actualmax = actualmax + minrange / 2
    end
    
    self.plotter:clear(self.bg)

    self.plotter:chartGrid(self.MAX_ENTRIES, actualmin, actualmax, self.gridOffsetX, colors.gray, {
        xGap = 10,
        yLinesMin = 5, -- yLinesMin: number >= 1
        yLinesFactor = 2 -- yLinesFactor: integer >= 2
        -- effective max density = yMinDensity * yBasis
    })

    self.plotter:chartLine(self.plotData, self.MAX_ENTRIES, actualmin, actualmax, self.fg)

    local maxString = t.shortnum2(actualmax)
    local minString = t.shortnum2(actualmin)

    self.win.setVisible(false)

    self.plotter:render()

    self.win.setTextColor(self.fg)
    self.win.setBackgroundColor(self.bg)
    if not flatlabel then
        self.win.setCursorPos(self.plotter.box.term_width - #maxString + 1, 1)
        self.win.write(maxString)

        self.win.setCursorPos(self.plotter.box.term_width - #minString + 1, self.plotter.box.term_height)
        self.win.write(minString)
    else
        self.win.setCursorPos(self.plotter.box.term_width - #flatlabel + 1, self.plotter.math.round(self.plotter.box.term_height / 2))
        self.win.write(flatlabel)
    end

    self.win.setVisible(true)
end

return ChartLineOutputAdapter
end,

["telem.lib.util"] = function()
--------------------
-- Module: 'telem.lib.util'
--------------------
-- TODO write my own pretty_print
local pretty = require 'cc.pretty' or { pretty_print = print }

local function tsleep(num)
    local sec = tonumber(os.clock() + num)
    while (os.clock() < sec) do end
end

local function log(msg)
    print('TELEM :: '..msg)
end

local function err(msg)
    error('TELEM :: '..msg)
end

local function pprint(dater)
    return pretty.pretty_print(dater)
end

-- via https://www.lua.org/pil/19.3.html
local function skpairs(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0
    local iter = function ()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

local function shortnum(n)
    if n >= 10^11 then
        return string.format("%i G", n / 10^9)
    elseif n >= 10^10 then
        return string.format("%.1fG", n / 10^9)
    elseif n >= 10^9 then
        return string.format("%.2fG", n / 10^9)
    elseif n >= 10^8 then
        return string.format("%i M", n / 10^6)
    elseif n >= 10^7 then
        return string.format("%.1fM", n / 10^6)
    elseif n >= 10^6 then
        return string.format("%.2fM", n / 10^6)
    elseif n >= 10^5 then
        return string.format("%i k", n / 10^3)
    elseif n >= 10^4 then
        return string.format("%.1fk", n / 10^3)
    elseif n >= 10^3 then
        return string.format("%.2fk", n / 10^3)
    elseif n >= 10^2 then
        return string.format("%.1f", n)
    elseif n >= 10^1 then
        return string.format("%.2f", n)
    else
        return string.format("%.3f", n)
    end
end

-- based on https://rosettacode.org/wiki/Suffixation_of_decimal_numbers#Python
local function shortnum2(num, digits, base)
    if not base then base = 10 end

    local suffixes = {'', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y', 'X', 'W', 'V', 'U', 'googol'}

    local exponent_distance = 10
    if base == 2 then
        exponent_distance = 10
    else
        exponent_distance = 3
    end

    num = string.gsub(num, ',', '')
    local num_sign = string.sub(num, 1, 1) == '+' or string.sub(num, 1, 1) == '-' and string.sub(num, 1, 1) or ''

    num = math.abs(tonumber(num))

    local suffix_index = 0
    if base == 10 and num >= 1e100 then
        suffix_index = 13
        num = num / 1e100
    elseif num > 1 then
        local magnitude = math.floor(math.log(num, base))
        suffix_index = math.min(math.floor(magnitude / exponent_distance), 12)
        num = num / (base ^ (exponent_distance * suffix_index))
    end

    local num_str = ''
    if digits then
        num_str = string.format('%.' .. digits .. 'f', num)
    else
        num_str = string.format('%.3f', num):gsub('0+$', ''):gsub('%.$', '')
    end

    return num_sign .. num_str .. suffixes[suffix_index + 1] .. (base == 2 and 'i' or '')
end

local function constrainAppend (data, value, width)
    local removed = 0

    table.insert(data, value)

    while #data > width do
        table.remove(data, 1)
        removed = removed + 1
    end

    return removed
end

local function indexOf (tab, value)
    if type(value) == 'nil' then return -1 end
    
    for i,v in ipairs(tab) do
        if v == value then
            return i
        end
    end

    return -1
end

return {
    log = log,
    err = err,
    pprint = pprint,
    skpairs = skpairs,
    sleep = os.sleep or tsleep,
    shortnum = shortnum,
    shortnum2 = shortnum2,
    constrainAppend = constrainAppend,
    indexOf = indexOf
}
end,

----------------------
-- Modules part end --
----------------------
        }
        if files[path] then
            return files[path]
        else
            return origin_seacher(path)
        end
    end
end
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------
local _Telem = {
    _VERSION = '0.5.0',
    util = require 'telem.lib.util',
    input = require 'telem.lib.input',
    output = require 'telem.lib.output',
    
    -- API
    backplane = require 'telem.lib.Backplane',
    metric = require 'telem.lib.Metric',
    metricCollection = require 'telem.lib.MetricCollection'
}

local args = {...}

if #args < 1 or type(package.loaded['telem']) ~= 'table' then
    print('Telem ' .. _Telem._VERSION)
    print(' * A command-line interface is not yet implemented, please use require()')
end

return _Telem