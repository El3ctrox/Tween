--!strict

--// Packages
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Observer = Fusion.Observer
local Value = Fusion.Value
local xtypeof = Fusion.xtypeof
local peek = Fusion.peek

type Promise = typeof(Promise.new())
type CanBeState<T> = Fusion.CanBeState<T>
type State<T> = Fusion.Value<T>

local lerpers = require(script.Lerpers)
local styles = require(script.Styles)

--[=[
    @class Tween
]=]
local Tween = { styles = styles, lerpers = lerpers }

--[=[
    @within Tween
    @type state { repeatingCount: number?, repeatedCount: number?, playingCount: number?, playedCount: number?, totalSeconds: number?, reversedFade: number?, isReversing: boolean?, fade: number? }
    
    A type which describes Tween state
]=]
type state = {
    repeatingCount: number?,
    repeatedCount: number?,
    playingCount: number?,
    playedCount: number?,
    totalSeconds: number?,
    reversedFade: number?,
    isReversing: boolean?,
    fade: number?,
}

--[=[
    @within Tween
    @type tweenInfo { style: ((fade: number) -> number)?, duration: number, startDelay: number?, repeatCount: number?, repeatDelay: number?, reverseDelay: number?, shouldReverse: boolean? }
    
    A type which describes Tween behavior, like repeat count, if should reverse, delays, etc
]=]
export type tweenInfo = {
    style: ((fade: number) -> number)?,
    duration: number,
    playCount: number?,
    startDelay: number?,
    repeatCount: number?,
    repeatDelay: number?,
    reverseDelay: number?,
    shouldReverse: boolean?,
}
local function extractTweenInfo(tweenInfo: TweenInfo): tweenInfo
    
    return {
        style = styles[tweenInfo.EasingDirection.Name..tweenInfo.EasingStyle.Name] or styles.Linear,
        shouldReverse = tweenInfo.Reverses,
        repeatCount = tweenInfo.RepeatCount,
        repeatDelay = tweenInfo.DelayTime,
        duration = tweenInfo.Time,
    }
end

--// Constructor
function Tween:_wrap<TweenType>(consumer: (value: TweenType) -> (), _tweenInfo: TweenInfo|tweenInfo, origin: CanBeState<TweenType>, goal: CanBeState<TweenType>)
    
    local tweenInfo = if typeof(_tweenInfo) == "TweenInfo" then extractTweenInfo(_tweenInfo) else _tweenInfo
    if tweenInfo.repeatCount then tweenInfo.playCount = tweenInfo.repeatCount + 1 end
    if tweenInfo.playCount then tweenInfo.repeatCount = tweenInfo.playCount - 1 end
    
    local originValue, goalValue = peek(origin), peek(goal)
    local getLerper = lerpers[xtypeof(originValue)] or lerpers.default
    
    local lerper, param1, param2 = getLerper(originValue, goalValue)
    local getMultiplier = tweenInfo.style or styles.Linear
    
    local shouldReverse = tweenInfo.shouldReverse or false
    local reverseDelay = tweenInfo.reverseDelay or 0
    local repeatDelay = tweenInfo.repeatDelay or 0
    local repeatCount = tweenInfo.repeatCount or 0
    local startDelay = tweenInfo.startDelay or 0
    local playCount = tweenInfo.playCount or 1
    local duration = tweenInfo.duration or 0
    
    local reversionDuration = if shouldReverse then reverseDelay + duration else 0
    
    --[=[
        @within Tween
        @prop origin CanBeState<TweenType>
    ]=]
    self.origin = origin
    
    --[=[
        @within Tween
        @prop goal CanBeState<TweenType>
    ]=]
    self.goal = goal
    
    --[=[
        @within Tween
        @prop style (fade: number) -> number
        A function which receives tween progression and returns the multiplier for lerping
    ]=]
    self.style = getMultiplier
    
    --[=[
        @within Tween
        @prop shouldReverse boolean
    ]=]
    self.shouldReverse = shouldReverse
    
    --[=[
        @within Tween
        @prop reverseDelay number
    ]=]
    self.reverseDelay = reverseDelay
    
    --[=[
        @within Tween
        @prop repeatDelay number
    ]=]
    self.repeatDelay = repeatDelay
    
    --[=[
        @within Tween
        @prop repeatCount integer
    ]=]
    self.repeatCount = repeatCount
    
    --[=[
        @within Tween
        @prop startDelay number
    ]=]
    self.startDelay = startDelay
    
    --[=[
        @within Tween
        @prop playCount integer
    ]=]
    self.playCount = playCount
    
    --[=[
        @within Tween
        @prop duration number
    ]=]
    self.duration = duration
    
    --[=[
        @within Tween
        @prop totalDuration number
    ]=]
    self.totalDuration = startDelay + duration + reversionDuration
        + repeatCount * (repeatDelay + duration + reversionDuration)
    
    type run_profile = {} -- unique data for every tween:play, maybe insert callbacks here
    local runningProfile: run_profile?
    local startedTimestamp = -1
    
    local isGlobalReversing = false --TODO
    local hasCompleted = false
    local isReversing = false
    local playedCount = 0
	local fade = 0
    
    --// Listeners
    local disconnectOrigin, disconnectGoal
    
    if xtypeof(origin) == "State" then
        
        disconnectOrigin = Observer(origin):onChange(function()
            
            originValue = peek(origin)
            lerper, param1, param2 = getLerper(originValue, goalValue)
        end)
    end
    if xtypeof(goal) == "State" then
        
        disconnectGoal = Observer(goal):onChange(function()
            
            goalValue = peek(goal)
            lerper, param1, param2 = getLerper(originValue, goalValue)
        end)
    end
    
    --[=[
        @within Tween
        @method setState
        @param state state
        
        Updates the tween state, but not update his consumer
        If you need update consumer together, you can use (Tween:lerp)[/api/Tween#lerp]
    ]=]
    function self:setState(state: state)
        
        if state.totalSeconds then
            
            fade = (state.totalSeconds - self.startDelay) / duration
            
            while fade >= 1 do
                
                if shouldReverse and not isReversing then
                    
                    isReversing = true
                    fade -= 1
                    
                elseif playedCount+1 < playCount then
                    
                    isReversing = false
                    playedCount += 1
                    fade -= 1
                else
                    
                    hasCompleted = true
                    fade = 1
                    
                    break
                end
            end
            
            self:styledLerp(if isReversing then 1-fade else fade)
        end
        
        playedCount = state.playedCount or playedCount
        isReversing = state.isReversing or isReversing
        fade = state.fade or fade
    end
    --[=[
        @within Tween
        @method getState
        @return state
        @tag unique-table
    ]=]
    function self:getState(): state
        
        return {
            playingCount = playedCount+1,
            playedCount = playedCount,
            
            repeatingCount = playedCount,
            repeatedCount = math.max(0, playedCount-1),
            
            reversedFade = if isReversing then 1-fade else fade,
            isReversing = isReversing,
            fade = fade,
            
            totalSeconds = -1   --TODO
        }
    end
    
    --[=[
        @within Tween
        @type play_params state & { delay: number? }
    ]=]
    type play_params = state & { delay: number? }
    
    --[=[
        @within Tween
        @method playAsync
        @param params play_params
        @return Promise
        
        Wraps [Tween:awaitPlay](/api/Tween#awaitPlay) with a new [Promise](https://eryn.io/roblox-lua-promise/api/Promise)
    ]=]
    function self:playAsync(params: play_params?): Promise
        
        return Promise.try(self.awaitPlay, self, params)
    end
    --[=[
        @within Tween
        @method awaitPlay
        @param params play_params?  -- if nil, will keep the current state, else will be resetted and replaced
        @return boolean -- success: true = finished, false = cancelled
    ]=]
    function self:awaitPlay(params: play_params?): boolean
        
        local overElapsedTime = 0
        local delay = params and params.delay or 0
        
        if delay > 0 then
            
            overElapsedTime = task.wait(delay)
        else
            
            overElapsedTime -= delay
        end
        
        if params then self:setState(params) end
        
        runningProfile = {}
        return pcall(self._awaitRun, self, overElapsedTime)
    end
    
    --[=[
        @within Tween
        @method delayedCancelAsync
        @param delay number
        @return Promise
        
        Wraps [Tween:cancel](/api/Tween#cancel) with a new [Promise](https://eryn.io/roblox-lua-promise/api/Promise)
    ]=]
    function self:delayedCancelAsync(delay: number): Promise
        
        return Promise.delay(delay):andThenCall(self.stop, self)
    end
    --[=[
        @within Tween
        @method cancel
    ]=]
    function self:cancel()
        
        runningProfile = nil
    end
    
    --[=[
        @within Tween
        @method lerp
        @param state state
        @return TweenType
        
        Update Tween state, and [Tween:lerp](/api/Tween#lerp) his using your own style
    ]=]
    function self:lerp(state: state): TweenType
        
        self:setState(state)
        return self:rawLerp(getMultiplier(if isReversing then 1-fade else fade))
    end
    --[=[
        @within Tween
        @method rawLerp
        @param progression number
        @return TweenType
        
        Returns [Tween.origin](/api/Tween#origin) lerped to [Tween.goal](/api/Tween#goal) using given multiplier
        Doesnt update Tween state
    ]=]
    function self:rawLerp(multiplier: number): TweenType
        
        local value = lerper(param1, param2, multiplier)
        consumer(value)
        
        return value
    end
    
    --[=[
        @within Tween
        @method hasCompleted
        @return boolean
    ]=]
    function self:hasCompleted(): boolean
        
        return hasCompleted
    end
    --[=[
        @within Tween
        @method isPlaying
        @return boolean
    ]=]
    function self:isPlaying(): boolean
        
        return startedTimestamp > -1
    end
    
    --[=[
        @within Tween
        @method destroy
    ]=]
    function self:destroy()
        
        self:cancel()
        
        disconnectOrigin()
        disconnectGoal()
        table.clear(self)
    end
    
    function self:_awaitRun(overElapsedTime: number)
        
        local currentRunningProfile = runningProfile :: run_profile
        
        startedTimestamp = os.clock() + startDelay
            - if isReversing then reverseDelay + duration else 0
            - (playedCount-1)*(repeatDelay + duration)
            - overElapsedTime
            - fade*duration
        
        repeat
            local deltaTime = task.wait()
            assert(runningProfile == currentRunningProfile, 'cancelled')
            
            self:_update(deltaTime)
            
        until hasCompleted
        
        startedTimestamp = -1
        runningProfile = nil
    end
    function self:_update(deltaTime: number)
        
        fade += deltaTime/duration
        if os.clock() < startedTimestamp then return end
        
        --// Stage Completion
        while fade >= 1 do
            
            if shouldReverse and not isReversing then
                
                startedTimestamp += reverseDelay + duration
                isReversing = true
                fade -= 1
                
            elseif playedCount+1 < playCount then
                
                startedTimestamp += repeatDelay + duration
                isReversing = false
                playedCount += 1
                fade -= 1
            else
                
                hasCompleted = true
                fade = 1
                
                break
            end
        end
        
        self:styledLerp(if isReversing then 1-fade else fade)
    end
    
    --// End
    return self
end

--[=[
    @within Tween
    @function binded
    @param consumer (value: TweenType) -> ()    -- receives origin lerped to goal
    @param tweenInfo TweenInfo|tweenInfo        -- describes tween behavior
    @param origin CanBeState<TweenType>         -- initial point for lerping
    @param goal CanBeState<TweenType>           -- final point for lerping, must to be same type of origin (not needed be a state, just same stored type)
    @return Tween
    
    TweenType is a generic type, must to be your type registred in [Tween.lerpers](/api/Tween#lerpers)
    Construct a new Tween object, binded with consumer. Every frame update will be passed interpolated value for consumer given
]=]
function Tween.binded<V>(consumer: (value: V) -> (), _tweenInfo: TweenInfo|tweenInfo, origin: CanBeState<V>, goal: CanBeState<V>): Tween<V>
    
    local self = { type = "Tween", kind = "Binded" }
    return Tween._wrap(self, consumer, _tweenInfo, origin, goal)
end
--[=[
    @within Tween
    @function binded
    @param tweenInfo TweenInfo|tweenInfo        -- describes tween behavior
    @param origin CanBeState<TweenType>         -- initial point for lerping
    @param goal CanBeState<TweenType>           -- final point for lerping, must to be same type of origin (not needed be a state, just same stored type)
    @return Tween
    
    Construct a new Tween object extending Fusion Value
]=]
function Tween.state<V>(_tweenInfo, origin: CanBeState<V>, goal: CanBeState<V>): TweenState<V>
    
    local self = Value(origin)
    self.kind = "ernisto/Tween"
    
    local function syncState(value: V)
        
        self:set(value)
    end
    
    return Tween._wrap(self, syncState, _tweenInfo, origin, goal)
end
--[=[
    @within Tween
    @function sequence
    @param tweens {Tween}?
    @return TweenSequence
]=]
function Tween.sequence(_duration: number?, _tweens: {Tween<any>}?): TweenSequence
    
    --[=[
        @class TweenSequence
    ]=]
    local self = { type = "Tween", kind = "Sequence" }
    local duration = _duration or 0
    local keypointTweens = {}
    
    local playingTweensPromise = nil
    local startedTimestamp = -1
    local hasCompleted = false
    local isReversing = false
    local totalSeconds = 0
    local fade = 0
    
    function self:setState(state: state)
    end
    function self:getState(): state
        
        return {
            playingCount = 1,
            playedCount = if hasCompleted then 1 else 0,
            
            repeatingCount = 0,
            repeatedCount = 0,
            
            reversedFade = if isReversing then 1-fade else fade,
            isReversing = isReversing,
            fade = fade,
            
            totalSeconds = -1   --TODO
        }
    end
    
    function self:playAsync(params: state?)
        
        if params then self:setState(params) end
        
        local tweenPromises = {}
        
        for timestamp, tweens in keypointTweens do
            
            for _,tween in tweens do
                
                local tweenPromise = if isReversing
                    then tween:playAsync{ delay = totalSeconds - timestamp + tween.totalDuration, isReversing = true }
                    else tween:playAsync{ delay = timestamp - totalSeconds, isReversing = false }
                
                table.insert(tweenPromises, tweenPromise)
            end
        end
        
        playingTweensPromise = Promise.all(tweenPromises)
        return playingTweensPromise
    end
    function self:awaitPlay(params: state?)
        
        return self:playAsync(params):await()
    end
    
    function self:delayedCancelAsync(delay: number)
        
        return Promise.delay(delay):andThenCall(self.stop, self)
    end
    function self:cancel()
        
        if playingTweensPromise then playingTweensPromise:cancel() end
    end
    
    function self:lerp(state: state)
        
        self:setState(state)
        
        for timestamp, tweens in keypointTweens do
            
            for _,tween in tweens do
                
                tween:lerp{ isReversing = isReversing,
                    totalSeconds = if isReversing
                    then (duration - state.totalSeconds) - (timestamp + tween.duration)
                    else state.totalSeconds - timestamp
                }
            end
        end
    end
    function self:rawLerp(multiplier: number)   -- TODO
        
        error(`not finished yet`)
        
        for timestamp, tweens in keypointTweens do
            
            local timestampFade = timestamp/duration
            
            for _,tween in tweens do
                
                tween:rawLerp(if isReversing
                    then (1 - multiplier) - (timestamp + tween.duration)
                    else multiplier - 0
                )
            end
        end
    end
    
    function self:hasCompleted(): boolean
        
        return hasCompleted
    end
    function self:isPlaying(): boolean
        
        return startedTimestamp > -1
    end
    
    function self:add(tween: Tween<any>, keypoint: number)
        
        if tween.repeatCount > 0 then warn(`repetition isnt supported yet`) end
        if tween.shouldReverse then warn(`reversion isnt supported yet`) end
        
        duration = math.max(duration, keypoint + tween.totalDuration)
        
        local tweens = keypointTweens or {}
        keypointTweens[keypoint] = tweens
        
        table.insert(tweens, tween)
    end
    
    --// Setup
    for _,tween in _tweens do self:add(tween) end
    
    --// End
    return self
end
--[=[
    @within Tween
    @function builder
    @return TweenBuilder
]=]
function Tween.builder(): TweenBuilder
    
    --[=[
        @class TweenBuilder
    ]=]
	local self = { type = "TweenBuilder" }
    
    local tween: Tween<any>?
    local consumer
    local origin
    local goal
    local info
    
    --[=[
        @within TweenBuilder
        @method from
        @param origin lerpable
        @return TweenBuilder
        
        Defines Tween origin
    ]=]
    function self:from(_origin: any): TweenBuilder
        
        origin = _origin
        return self
    end
    --[=[
        @within TweenBuilder
        @method to
        @param goal lerpable
        @return TweenBuilder
        
        Defines Tween goal
    ]=]
    function self:to(_goal: any): TweenBuilder
        
        origin = _goal
        goal = _goal
        return self
    end
    --[=[
        @within TweenBuilder
        @method with
        @param info TweenInfo|tweenInfo
        @return TweenBuilder
        
        Defines Tween info
    ]=]
    function self:with(_info: TweenInfo|tweenInfo): TweenBuilder
        
        info = _info
        return self
    end
    --[=[
        @within TweenBuilder
        @method binded
        @param consumer (value: lerpable) -> ()
        @return TweenBuilder
        
        Defines the Tween consumer, and does [TweenBuilder:get](/api/TweenBuilder#get) returns a [Tween](/api/Tween) instead [TweenState](/api/TweenState)
    ]=]
    function self:binded(_consumer: (value: any) -> ()): TweenBuilder
        
        consumer = _consumer
    end
    --[=[
        @within TweenBuilder
        @method get
        @return Tween|TweenState
        @tag cached-result
        
        Creates a [Tween](/api/Tween) with given data if consumer has defined, else creates a [TweenState](/api/TweenState)
    ]=]
    function self:get()
        
        assert(goal, `goal didnt definied (use :to)`)
        assert(info, `info didnt definied (use :with)`)
        
        if not tween then
            
            tween = if consumer then Tween.binded(consumer, info, origin, goal)
                else Tween.state(info, origin, goal)
        end
        
        return tween
    end
    
    --// End
    return table.freeze(self)
end

--// End
export type TweenSequence = Tween<nil> & typeof(Tween.sequence())
export type TweenBuilder = typeof(Tween.builder())
export type TweenState<V> = Tween<V> & State<V>

export type Tween<V> = typeof(Tween._wrap({}))
return Tween