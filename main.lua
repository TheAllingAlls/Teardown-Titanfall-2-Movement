#version 2

--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function server.init()
end

function server.tick(dt)
end

function server.update(dt)
end

function client.init()
    client.player_controller_init()
end

function client.tick(delta)
    client.player_controller_tick()
end

function client.render(delta)
    client.player_controller_render(delta)
end

function client.update(delta)
    client.player_controller_update(delta)
end

function client.postUpdate()
    client.player_controller_postUpdate()
end

function client.draw()
end


function client.player_controller_init()
    Purple = {r=0.5,g=0,b=0.5,a=1}
    Pink = {r=1,g=0,b=1,a=1}
    Yellow = {r=1,g=1,b=0,a=1}
    Red = {r=1,g=0,b=0,a=1}
    LightBlue = {r=0.1,g=0.1,b=1,a=1}
    LightGreen = {r=0.1,g=1,b=0.1,a=1}
    Orange = {r=1,g=0.5,b=0,a=1}
end
function client.player_controller_render(delta)
    local pos = SelectedTransform.pos

    DebugCross(pos, Purple.r, Purple.g, Purple.b, 1)

    DebugLine(pos, LookDirection, Yellow.r, Yellow.g, Yellow.b, 1)
    DebugCross(LookDirection, Yellow.r, Yellow.g, Yellow.b, 1)
    DebugLine(pos, LeftDirection, Red.r, Red.g, Red.b, 1)
    DebugCross(LeftDirection, Red.r, Red.g, Red.b, 1)
    DebugLine(pos, RightDirection, LightBlue.r, LightBlue.g, LightBlue.b, 1)
    DebugCross(RightDirection, LightBlue.r, LightBlue.g, LightBlue.b, 1)
    DebugLine(pos, BackDirection, LightGreen.r, LightGreen.g, LightGreen.b, 1)

    DebugCross(CastHitPosition, Pink.r, Pink.g, Pink.b, 1)
    DebugLine(CastHitPosition, CastHitNormal, Pink.r, Pink.g, Pink.b, 1)
end
function client.player_controller_draw()
end
function client.player_controller_update(delta)
end
function client.player_controller_postUpdate()
end
function client.player_controller_tick(delta)
    FallCheck() --Attempt to basically disable fall damage
    JumpKit() --Double jump, includes coyote jumping and velocity changes on air jumps
    Sliding() --Basic sliding, plus the slide boost with a two-second cooldown
    LookForWalls() --Wallrunning
end

function LookForWalls()
    LookDistance = 5
    OriginOffset = 1 - (GetPlayerCrouch(0)/2)
    EyeTransform = GetPlayerEyeTransform(0)
    PlayerTransform = GetPlayerTransform(0)
    SelectedTransform = PlayerTransform
    SelectedTransform = Transform(Vec(SelectedTransform.pos[1], SelectedTransform.pos[2] + OriginOffset, SelectedTransform.pos[3]), SelectedTransform.rot)

    IsOccupied = 0 --Whether or not player is occupied with a current shape
    CurrentOccupant = 0
    Forward = Vec(0, 0, -LookDistance)
    Left = Vec(LookDistance, 0, 0)
    Right = Vec(-LookDistance, 0, 0)
    Back = Vec(0, 0, LookDistance)
    LookDirection = TransformToParentPoint(SelectedTransform, Forward)
    LeftDirection = TransformToParentPoint(SelectedTransform, Left)
    RightDirection = TransformToParentPoint(SelectedTransform, Right)
    BackDirection = TransformToParentPoint(SelectedTransform, Back)
    CastDirections = {Forward,Left,Right,Back}
    CastInfo = {hit=false, distance=0, normal=Vec(0,0,0), shape=0}
    CastDirection = Vec(0,0,0)
    CastHitPosition = Vec(0,0,0)
    CastHitNormal = Vec(0,0,0)

    for i = 1, table.maxn(CastDirections), 1 do
        CastInfo.hit,CastInfo.distance,CastInfo.normal,CastInfo.shape = QueryRaycast(SelectedTransform.pos, CastDirections[i], LookDistance, 0, false)
        if CastInfo.hit == true then
            CastDirection = CastDirections[i]
        else
            CastDirection = Vec(0,0,0)
        end
    end
    if CastInfo.hit == true then
        CastHitPosition = (VecAdd(SelectedTransform.pos, VecScale(CastDirection, CastInfo.distance)))
        CastHitNormal = (VecAdd(CastHitPosition, CastInfo.normal))
    else
        CastHitPosition = Vec(0,0,0)
        CastHitNormal = Vec(0,0,0)
    end

    DebugWatch("CastInfo",CastInfo,false)
    DebugWatch("CastDirection",CastDirection,false)
    DebugWatch("CastHitPosition",CastHitPosition,false)
end

JumpState = 0
MaxAirJumps = 1
AirJumps = 0
JumpBufferMax = 0.125
JumpBuffer = 0.0
JumpVelocity = 6
PreForceDir = Vec(0,0,0)
Force = 0
ForceDir = Vec(0,0,0)
ForceDirection = Vec(0,0,0)
ForceMultiplierDefault = 6
ForceMultiplier = Vec(ForceMultiplierDefault, 0, ForceMultiplierDefault)
function JumpKit()
    local delta = GetTimeStep()

    local player = GetLocalPlayer()
    Up = GetPlayerUp(0)
    local playerVelocity = GetPlayerVelocity(0)
    local playerVelocityLengthXZ = VecLength(Vec(playerVelocity[1],0,playerVelocity[3]))
    local eyeTransform = GetPlayerEyeTransform(0)
    local playerTransform = GetPlayerTransform(0)
    local baseTransform = Transform(Vec(0,0,0),playerTransform.rot)

    if InputDown("up",0) or InputDown("down",0) or InputDown("left",0) or InputDown("right",0) then
        Force = 1
    else
        Force = 0
    end
    if InputValue("up", 0) > 0 and InputValue("down", 0) == 0 then
        PreForceDir[3] = -InputValue("up", 0)
    elseif InputValue("down", 0) > 0 and InputValue("up", 0) == 0 then
        PreForceDir[3] = InputValue("down", 0)
    else
        PreForceDir[3] = 0
    end
    if InputValue("left", 0) > 0 and InputValue("right", 0) == 0 then
        PreForceDir[1] = -InputValue("left", 0)
    elseif InputValue("right", 0) > 0 and InputValue("left", 0) == 0 then
        PreForceDir[1] = InputValue("right", 0)
    else
        PreForceDir[1] = 0
    end
    for i = 0, table.maxn(PreForceDir) do
        if PreForceDir[i] then
            if i ~= 2 then
                if PreForceDir[i] > 1 then
                    PreForceDir[i] = 1
                elseif PreForceDir[i] < -1 then
                    PreForceDir[i] = -1
                end
            end
        end
    end
    ForceDirection = TransformToParentPoint(baseTransform,PreForceDir)
    -- if VecLength(PreForceDir) > 1 then
    --     PreForceDir = VecNormalize(ForceDir)
    -- end
    if PreForceDir[2] ~= 0.0 then
        PreForceDir[2] = 0.0
    end
    ForceDir = Vec(0,0,0)
    DebugWatch("X Velocity", playerVelocity[1], false)
    DebugWatch("Z Velocity", playerVelocity[3], false)
    DebugWatch("XZ Velocity Length", playerVelocityLengthXZ, false)
    for i = 0, table.maxn(ForceMultiplier), 1 do
        if ForceMultiplier[i] then
            if i ~= 2 then
                if playerVelocity[i] > 0 then
                    if ForceDirection[i] > 0 then
                        if playerVelocityLengthXZ > ForceMultiplierDefault+1 then
                            ForceMultiplier[i] = 0
                            Force = 0
                        else
                            ForceMultiplier[i] = ForceMultiplierDefault
                        end
                    else
                        ForceMultiplier[i] = ForceMultiplierDefault
                    end
                elseif playerVelocity[i] < 0 then
                    if ForceDirection[i] < 0 then
                        if playerVelocityLengthXZ > ForceMultiplierDefault+1 then
                            ForceMultiplier[i] = 0
                            Force = 0
                        else
                            ForceMultiplier[i] = ForceMultiplierDefault
                        end
                    else
                        ForceMultiplier[i] = ForceMultiplierDefault
                    end
                end
            end
        end
    end
    -- ForceDir = VecScale(ForceDirection, ForceMultiplier)
    ForceDir[1] = ForceDirection[1] * ForceMultiplier[1]
    ForceDir[3] = ForceDirection[3] * ForceMultiplier[3]
    -- DebugLine(playerTransform.pos, VecAdd(playerTransform.pos,ForceDir), Orange.r, Orange.g, Orange.b, 1)

    if IsPlayerGrounded(0) == true then
        AirJumps = MaxAirJumps
        if JumpState >= 3 then
            JumpState = 0
        end
        JumpBuffer = JumpBufferMax
    else
        if JumpState == 0 then
            if JumpBuffer > 0.0 then
                JumpBuffer = JumpBuffer - delta
            end
        end
        if JumpBuffer <= 0.0 then
            if JumpBuffer ~= -1.0 then
                JumpBuffer = -1.0
            end
    end
    end
    if InputPressed("jump", 0) then
        if JumpState == 0 or JumpState == 4 then
            JumpState = 1
        end
        if JumpBuffer == -1.0 then
            if JumpState ~= 3 then
                JumpState = 1
                JumpBuffer = 0.0
            end
        end
    end
    if InputReleased("jump", 0) then
        if JumpState == 2 then
            if AirJumps > 0 then
                JumpState = 4
            else
                JumpState = 3
            end
        end
    end
    if AirJumps > 0 then
        if JumpState == 1 then
            if IsPlayerJumping(0) == true or IsPlayerGrounded(0) == false then
                if IsPlayerJumping(0) == true then
                    ForceDir = Vec(0,0,0)
                    Force = 0
                end
                if JumpBuffer < JumpBufferMax and JumpBuffer > 0.0 then
                    ForceDir = Vec(0,0,0)
                    Force = 0
                end
                ServerCall("server.setPlayerVelocity", player, playerVelocity, ForceDir, Force)
                if IsPlayerGrounded(0) == false then
                    AirJumps = AirJumps - 1
                    if JumpBuffer > 0.0 and JumpBuffer ~= JumpBufferMax then
                        AirJumps = AirJumps + 1
                        JumpBuffer = -1.0
                    end
                end
                JumpState = 2
            end
        end
    end
    -- DebugWatch("AirJumps",AirJumps,false)
    -- DebugWatch("JumpBuffer",JumpBuffer,false)
    -- DebugWatch("JumpState",JumpState,false)
    DebugWatch("ForceDir",ForceDir,false)
end
function server.setPlayerVelocity(playerId, playerVelocity, forceDir, force)
    local newVelocity = Vec((playerVelocity[1]*-(force-1)) + forceDir[1], (playerVelocity[2]*AirJumps) + (JumpVelocity+(AirJumps*5)), (playerVelocity[3]*-(force-1)) + forceDir[3])
    SetPlayerVelocity(newVelocity, playerId)
    -- DebugWatch("server.ForceDir",forceDir,false)
    -- DebugWatch("","Applying Jumpkit boost...",false)
end

SlideCooldownMax = 2.0
SlideCooldown = SlideCooldownMax
SlideReady = 0
function Sliding()
    if InputValue("up",0) > 0 then
        if SlideReady ~= 2 then
            SlideReady = 1
        end
    else
        SlideReady = 0
    end
    if VecLength(ForceDir) > 0 then
        DebugWatch("ForceDir from JumpKit()",ForceDir,false)
    end
end

FallCheckDir = Vec(0,-1,0)
FallCheckDistanceMultiplier = 0.4
FallCheckCastRadius = 1
FallCheckCast = {hit=false,dist=0,normal=Vec(),shape=0}
FallMaxVelocity = -10
FallVelocityMultiplier = 0.99
function FallCheck()
    local player = GetLocalPlayer()
    local playerVelocity = GetPlayerVelocity(0)
    local playerTransform = GetPlayerTransform(0)
    if playerVelocity[2] < FallMaxVelocity then
        FallCheckCast.hit,FallCheckCast.dist,FallCheckCast.normal,FallCheckCast.shape = QueryRaycast(playerTransform.pos, FallCheckDir, -playerVelocity[2]*FallCheckDistanceMultiplier, FallCheckCastRadius, false)
        if FallCheckCast.hit == true then
            ServerCall("server.preventFallDamage", player, playerVelocity)
            -- DebugWatch("","Applying Jumpkit hover...",false)
        end
    end
    -- DebugLine(playerTransform.pos, VecAdd(playerTransform.pos, VecScale(FallCheckDir, FallCheckCast.dist)), Pink.r, Pink.g, Pink.b, 1)
    -- DebugWatch("Y Velocity",playerVelocity[2],false)
    -- DebugWatch("FallCheckCast",FallCheckCast,false)
end
function server.preventFallDamage(playerId, playerVelocity)
    SetPlayerVelocity(Vec(playerVelocity[1], playerVelocity[2]*FallVelocityMultiplier, playerVelocity[3]), playerId)
end